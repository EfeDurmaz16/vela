defmodule VelaWeb.Api.V1.FoundationController do
  use VelaWeb, :controller

  alias Vela.{Accounts, Agents, Evidence, Forge, Idempotency, Integrations, Jobs, Webhooks}
  alias Vela.Outbox.OutboxEvent
  alias Vela.Repo

  import Ecto.Query

  def orgs(conn, params), do: paged(conn, Accounts.list_organizations(), params)
  def repos(conn, params), do: paged(conn, Forge.list_repositories(), params)
  def changes(conn, params), do: paged(conn, Forge.list_changes(), params)
  def pull_requests(conn, params), do: paged(conn, Forge.list_pull_requests(), params)
  def agents(conn, params), do: paged(conn, Agents.list_agent_profiles(), params)

  def evidence_events(conn, params),
    do: paged(conn, Evidence.list_recent_events(page_size(params)), params)

  def integrations(conn, params), do: paged(conn, Integrations.list_integrations(), params)

  def service_connections(conn, params),
    do: paged(conn, Integrations.list_service_connections(), params)

  def environments(conn, params), do: paged(conn, Integrations.list_environments(), params)

  def analysis_runs(conn, params) do
    runs = Vela.Maestro.AnalysisRun |> order_by([r], desc: r.inserted_at) |> Repo.all()
    paged(conn, runs, params)
  end

  def readiness_scores(conn, params) do
    scores = Vela.Maestro.ReadinessScore |> order_by([s], desc: s.inserted_at) |> Repo.all()
    paged(conn, scores, params)
  end

  def merge_candidates(conn, params) do
    candidates = Vela.Merge.MergeCandidate |> order_by([c], desc: c.inserted_at) |> Repo.all()
    paged(conn, candidates, params)
  end

  def releases(conn, params) do
    releases = Vela.Releases.ReleaseCandidate |> order_by([r], desc: r.inserted_at) |> Repo.all()
    paged(conn, releases, params)
  end

  def repo_trust(conn, %{"id" => id}) do
    json(conn, %{
      data: %{
        repository_id: id,
        signals: Enum.map(Forge.list_repository_trust_signals(id), &serialize/1)
      }
    })
  end

  def create_repo(conn, params) do
    attrs =
      params
      |> Map.take([
        "name",
        "slug",
        "visibility",
        "default_branch",
        "description",
        "provider",
        "external_id",
        "full_name",
        "html_url",
        "repo_cell_id",
        "health_status",
        "risk_level"
      ])
      |> Map.put("organization_id", conn.assigns.current_organization.id)

    with {:ok, repository} <- Forge.create_repository(attrs) do
      conn
      |> put_status(:created)
      |> json(%{data: serialize(repository)})
    else
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def show_repo(conn, %{"id" => id}) do
    with {:ok, repository} <- fetch_repo(conn, id) do
      json(conn, %{data: serialize(repository)})
    else
      {:error, :not_found} -> repo_not_found(conn)
    end
  end

  def update_repo(conn, %{"id" => id} = params) do
    with {:ok, repository} <- fetch_repo(conn, id),
         {:ok, repository} <-
           Forge.update_repository(
             repository,
             Map.take(params, [
               "name",
               "slug",
               "visibility",
               "default_branch",
               "description",
               "repo_cell_id",
               "health_status",
               "risk_level"
             ])
           ) do
      json(conn, %{data: serialize(repository)})
    else
      {:error, :not_found} -> repo_not_found(conn)
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def delete_repo(conn, %{"id" => id}) do
    with {:ok, repository} <- fetch_repo(conn, id),
         {:ok, _repository} <- Forge.delete_repository(repository) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} -> repo_not_found(conn)
      {:error, changeset} -> validation_error(conn, changeset)
    end
  end

  def import_github_repo(conn, %{"owner" => owner, "repo" => repo_name} = params) do
    provider = Map.get(params, "provider", "github")

    with :ok <- ensure_github_provider(provider),
         {:ok, repository} <- upsert_github_import_placeholder(conn, owner, repo_name) do
      idempotent_json(conn, repository.organization_id, fn ->
        {:ok, job} =
          Repo.transaction(fn ->
            {:ok, job} =
              Jobs.enqueue(:repo_import, %{
                organization_id: repository.organization_id,
                repository_id: repository.id,
                provider: "github",
                owner: owner,
                repo: repo_name
              })

            record_job_accepted!(conn, %{
              organization_id: repository.organization_id,
              repository_id: repository.id,
              event_type: "repo.import_queued",
              resource_type: "repository",
              resource_id: repository.id,
              job: job
            })

            job
          end)

        {202, %{data: %{repository: serialize(repository), job: job_payload(job)}}}
      end)
    else
      {:error, :unsupported_provider} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "unsupported_provider"}})

      {:error, changeset} ->
        validation_error(conn, changeset)
    end
  end

  def change_readiness(conn, %{"id" => id}) do
    scores =
      Vela.Maestro.ReadinessScore
      |> where([s], s.change_id == ^id)
      |> order_by([s], desc: s.inserted_at)
      |> Repo.all()

    json(conn, %{data: Enum.map(scores, &serialize/1)})
  end

  def agent_sessions(conn, %{"id" => id} = params) do
    sessions =
      Vela.Agents.AgentSession
      |> where([s], s.agent_actor_id == ^id)
      |> order_by([s], desc: s.started_at)
      |> Repo.all()

    paged(conn, sessions, params)
  end

  def agent_policies(conn, %{"id" => id} = params) do
    policies =
      Vela.Agents.AgentPolicy
      |> where([p], p.actor_id == ^id)
      |> order_by([p], asc: p.name)
      |> Repo.all()

    paged(conn, policies, params)
  end

  def import_repo(conn, %{"id" => id}) do
    repository = Repo.get!(Vela.Forge.Repository, id)

    idempotent_json(conn, repository.organization_id, fn ->
      {:ok, job} =
        Repo.transaction(fn ->
          {:ok, job} =
            Jobs.enqueue(:repo_import, %{
              organization_id: repository.organization_id,
              repository_id: repository.id,
              provider: conn.params["provider"] || "github",
              owner: conn.params["owner"],
              repo: conn.params["repo"] || repository.slug
            })

          record_job_accepted!(conn, %{
            organization_id: repository.organization_id,
            repository_id: repository.id,
            event_type: "repo.import_queued",
            resource_type: "repository",
            resource_id: repository.id,
            job: job
          })

          job
        end)

      {202, %{data: %{repository_id: id, job: job_payload(job)}}}
    end)
  end

  def simulate_merge(conn, %{"id" => id}) do
    candidate =
      Vela.Merge.MergeCandidate
      |> preload(:repository)
      |> Repo.get!(id)

    idempotent_json(conn, candidate.repository.organization_id, fn ->
      {:ok, job} =
        Repo.transaction(fn ->
          {:ok, job} =
            Jobs.enqueue(:merge_simulation, %{
              organization_id: candidate.repository.organization_id,
              repository_id: candidate.repository_id,
              merge_candidate_id: candidate.id,
              pull_request_id: candidate.pull_request_id
            })

          record_job_accepted!(conn, %{
            organization_id: candidate.repository.organization_id,
            repository_id: candidate.repository_id,
            event_type: "merge.queued",
            resource_type: "merge_candidate",
            resource_id: candidate.id,
            job: job
          })

          job
        end)

      {202, %{data: %{merge_candidate_id: id, job: job_payload(job)}}}
    end)
  end

  def webhook(
        conn,
        %{"provider" => provider, "organization_id" => organization_id, "actor_id" => actor_id} =
          params
      ) do
    with :ok <- Webhooks.verify_provider_request(provider, conn),
         :ok <-
           validate_webhook_context(organization_id, actor_id, Map.get(params, "repository_id")),
         {:ok, event} <-
           Integrations.record_event(%{
             provider: provider,
             organization_id: organization_id,
             actor_id: actor_id,
             repository_id: Map.get(params, "repository_id"),
             resource_type: "integration",
             payload:
               Map.drop(params, ["provider", "organization_id", "actor_id", "repository_id"])
           }) do
      conn
      |> put_status(:accepted)
      |> json(%{data: %{provider: provider, accepted: true, evidence_event_id: event.id}})
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "webhook_verification_failed", reason: to_string(reason)}})

      {:invalid_context, reason} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: %{code: "webhook_context_invalid", reason: to_string(reason)}})
    end
  end

  def webhook(conn, %{"provider" => provider}) do
    with :ok <- Webhooks.verify_provider_request(provider, conn) do
      conn
      |> put_status(:accepted)
      |> json(%{data: %{provider: provider, accepted: true, evidence_event_id: nil}})
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "webhook_verification_failed", reason: to_string(reason)}})
    end
  end

  defp paged(conn, entries, params) do
    page_size = page_size(params)

    json(conn, %{
      data: entries |> Enum.take(page_size) |> Enum.map(&serialize/1),
      pagination: %{limit: page_size, returned: min(length(entries), page_size)}
    })
  end

  defp page_size(params) do
    case Integer.parse(to_string(Map.get(params, "limit", "25"))) do
      {limit, ""} when limit > 0 and limit <= 100 -> limit
      _ -> 25
    end
  end

  defp serialize(%schema{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.reject(fn {_key, value} -> match?(%Ecto.Association.NotLoaded{}, value) end)
    |> Map.drop([:__meta__, :organization, :repository, :actor, :author_actor])
    |> Map.put(:type, schema |> Module.split() |> List.last() |> Macro.underscore())
  end

  defp fetch_repo(conn, id) do
    case Forge.get_repository_for_org(conn.assigns.current_organization.id, id) do
      nil -> {:error, :not_found}
      repository -> {:ok, repository}
    end
  end

  defp repo_not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{code: "repo_not_found"}})
  end

  defp validation_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "validation_failed", details: errors_on(changeset)}})
  end

  defp ensure_github_provider("github"), do: :ok
  defp ensure_github_provider(_provider), do: {:error, :unsupported_provider}

  defp upsert_github_import_placeholder(conn, owner, repo_name) do
    organization_id = conn.assigns.current_organization.id
    slug = repo_name |> to_string() |> String.downcase()

    attrs = %{
      name: repo_name,
      slug: slug,
      visibility: "private",
      default_branch: "main",
      health_status: "unknown",
      risk_level: "medium",
      provider: "github",
      full_name: "#{owner}/#{repo_name}",
      import_status: "pending",
      last_import_error: nil
    }

    case Forge.get_repository_by_slug_for_org(organization_id, slug) do
      nil -> Forge.create_repository(Map.put(attrs, :organization_id, organization_id))
      repository -> Forge.update_repository(repository, attrs)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp job_payload(%Oban.Job{} = job) do
    %{id: job.id, status: "queued", kind: job.args["kind"], queue: job.queue}
  end

  defp idempotent_json(conn, organization_id, fun) do
    actor_id = conn.assigns.current_actor.id

    case Idempotency.run(conn, organization_id, actor_id, fun) do
      {:ok, {status, body}} ->
        conn |> put_status(status) |> json(body)

      {:replay, {status, body}} ->
        conn |> put_status(status) |> json(body)

      {:conflict, reason} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: to_string(reason)}})
    end
  end

  defp record_job_accepted!(conn, attrs) do
    payload = %{
      job_id: attrs.job.id,
      job_kind: attrs.job.args["kind"],
      queue: attrs.job.queue,
      actor_id: conn.assigns.current_actor.id
    }

    {:ok, _event} =
      Evidence.append_event(%{
        organization_id: attrs.organization_id,
        repository_id: attrs.repository_id,
        actor_id: conn.assigns.current_actor.id,
        event_type: attrs.event_type,
        resource_type: attrs.resource_type,
        resource_id: attrs.resource_id,
        payload: payload
      })

    %OutboxEvent{}
    |> OutboxEvent.changeset(%{
      organization_id: attrs.organization_id,
      repository_id: attrs.repository_id,
      event_type: attrs.event_type,
      payload: Map.put(payload, :resource_id, attrs.resource_id),
      status: "pending"
    })
    |> Repo.insert!()
  end

  defp validate_webhook_context(organization_id, actor_id, repository_id) do
    with true <- resource_belongs_to?(Vela.Actors.Actor, actor_id, organization_id),
         true <-
           is_nil(repository_id) or
             resource_belongs_to?(Vela.Forge.Repository, repository_id, organization_id) do
      :ok
    else
      _ -> {:invalid_context, :tenant_mismatch}
    end
  end

  defp resource_belongs_to?(schema, id, organization_id) do
    case Repo.get(schema, id) do
      %{organization_id: ^organization_id} -> true
      _ -> false
    end
  end
end
