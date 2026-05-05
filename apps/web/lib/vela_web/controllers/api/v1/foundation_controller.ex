defmodule VelaWeb.Api.V1.FoundationController do
  use VelaWeb, :controller

  alias Vela.{Accounts, Agents, Evidence, Forge, Integrations, Jobs, Webhooks}
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

    {:ok, job} =
      Jobs.enqueue(:repo_import, %{
        organization_id: repository.organization_id,
        repository_id: repository.id,
        provider: conn.params["provider"] || "github",
        owner: conn.params["owner"],
        repo: conn.params["repo"] || repository.slug
      })

    conn
    |> put_status(:accepted)
    |> json(%{data: %{repository_id: id, job: job_payload(job)}})
  end

  def simulate_merge(conn, %{"id" => id}) do
    candidate =
      Vela.Merge.MergeCandidate
      |> preload(:repository)
      |> Repo.get!(id)

    {:ok, job} =
      Jobs.enqueue(:merge_simulation, %{
        organization_id: candidate.repository.organization_id,
        repository_id: candidate.repository_id,
        merge_candidate_id: candidate.id,
        pull_request_id: candidate.pull_request_id
      })

    conn
    |> put_status(:accepted)
    |> json(%{data: %{merge_candidate_id: id, job: job_payload(job)}})
  end

  def webhook(
        conn,
        %{"provider" => provider, "organization_id" => organization_id, "actor_id" => actor_id} =
          params
      ) do
    with :ok <- Webhooks.verify_provider_request(provider, conn),
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

  defp job_payload(%Oban.Job{} = job) do
    %{id: job.id, status: "queued", kind: job.args["kind"], queue: job.queue}
  end
end
