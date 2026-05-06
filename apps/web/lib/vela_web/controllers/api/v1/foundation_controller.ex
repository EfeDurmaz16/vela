defmodule VelaWeb.Api.V1.FoundationController do
  use VelaWeb, :controller

  alias Vela.{Accounts, Agents, Evidence, Forge, Integrations, RBAC, Repo}
  alias Vela.Merge.MergeCandidate
  alias Vela.Maestro.AnalysisRun
  alias VelaWeb.Api.V1.AnalysisActions
  alias VelaWeb.Api.V1.EvidenceActions
  alias VelaWeb.Api.V1.MergeActions
  alias VelaWeb.Api.V1.PullRequestActions
  alias VelaWeb.Api.V1.ReadModels
  alias VelaWeb.Api.V1.RepoActions
  alias VelaWeb.Api.V1.Response
  alias VelaWeb.Api.V1.WebhookActions

  def orgs(conn, params), do: Response.paged(conn, Accounts.list_organizations(), params)
  def repos(conn, params), do: Response.paged(conn, Forge.list_repositories(), params)
  def changes(conn, params), do: Response.paged(conn, Forge.list_changes(), params)
  def pull_requests(conn, params), do: Response.paged(conn, Forge.list_pull_requests(), params)
  def agents(conn, params), do: Response.paged(conn, Agents.list_agent_profiles(), params)

  def evidence_events(conn, params),
    do: Response.paged(conn, Evidence.list_recent_events(Response.page_size(params)), params)

  def verify_evidence(conn, params), do: EvidenceActions.verify_chain(conn, params)

  def integrations(conn, params),
    do: Response.paged(conn, Integrations.list_integrations(), params)

  def service_connections(conn, params),
    do: Response.paged(conn, Integrations.list_service_connections(), params)

  def environments(conn, params),
    do: Response.paged(conn, Integrations.list_environments(), params)

  def analysis_runs(conn, params) do
    Response.paged(conn, ReadModels.analysis_runs(), params)
  end

  def readiness_scores(conn, params) do
    Response.paged(conn, ReadModels.readiness_scores(), params)
  end

  def merge_candidates(conn, params) do
    Response.paged(conn, ReadModels.merge_candidates(), params)
  end

  def releases(conn, params) do
    Response.paged(conn, ReadModels.releases(), params)
  end

  def repo_trust(conn, %{"id" => id}) do
    json(conn, %{
      data: %{
        repository_id: id,
        signals: Enum.map(Forge.list_repository_trust_signals(id), &Response.serialize/1)
      }
    })
  end

  def create_repo(conn, params) do
    with :ok <- authorize(conn, :repository, :create) do
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
        |> json(%{data: Response.serialize(repository)})
      else
        {:error, changeset} -> Response.validation_error(conn, changeset)
      end
    else
      {:error, :forbidden} -> Response.forbidden(conn)
    end
  end

  def show_repo(conn, %{"id" => id}) do
    with {:ok, repository} <- fetch_repo(conn, id) do
      json(conn, %{data: Response.serialize(repository)})
    else
      {:error, :not_found} -> Response.repo_not_found(conn)
    end
  end

  def update_repo(conn, %{"id" => id} = params) do
    with {:ok, repository} <- fetch_repo(conn, id),
         :ok <- authorize(conn, :repository, :update),
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
      json(conn, %{data: Response.serialize(repository)})
    else
      {:error, :not_found} -> Response.repo_not_found(conn)
      {:error, :forbidden} -> Response.forbidden(conn)
      {:error, changeset} -> Response.validation_error(conn, changeset)
    end
  end

  def delete_repo(conn, %{"id" => id}) do
    with {:ok, repository} <- fetch_repo(conn, id),
         :ok <- authorize(conn, :repository, :delete),
         {:ok, _repository} <- Forge.delete_repository(repository) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} -> Response.repo_not_found(conn)
      {:error, :forbidden} -> Response.forbidden(conn)
      {:error, changeset} -> Response.validation_error(conn, changeset)
    end
  end

  def repo_readiness(conn, %{"id" => id}) do
    with {:ok, repository} <- fetch_repo(conn, id) do
      latest_signal = Forge.latest_repository_trust_signal(repository.id)

      json(conn, %{
        data: %{
          repository_id: repository.id,
          health_status: repository.health_status,
          risk_level: repository.risk_level,
          import_status: repository.import_status,
          open_pull_requests: Forge.count_open_pull_requests(repository.id),
          trust: trust_payload(latest_signal)
        }
      })
    else
      {:error, :not_found} -> Response.repo_not_found(conn)
    end
  end

  def sync_pull_request(conn, %{"id" => id, "number" => number}) do
    with {:ok, repository} <- fetch_repo(conn, id),
         :ok <- authorize(conn, :repository, :sync_pull_request),
         {:ok, number} <- parse_positive_integer(number) do
      RepoActions.sync_pull_request(conn, repository, number)
    else
      {:error, :not_found} ->
        Response.repo_not_found(conn)

      {:error, :forbidden} ->
        Response.forbidden(conn)

      {:error, :invalid_number} ->
        Response.validation_error(conn, %{errors: %{number: ["must be a positive integer"]}})
    end
  end

  def create_pr_comment(conn, %{"id" => id, "body" => body} = params) do
    with {:ok, pull_request} <- fetch_pull_request(conn, id),
         :ok <- authorize(conn, :review, :create) do
      PullRequestActions.create_comment(conn, pull_request, body, params)
    else
      {:error, :not_found} -> Response.pull_request_not_found(conn)
      {:error, :forbidden} -> Response.forbidden(conn)
    end
  end

  def queue_pr_merge(conn, %{"id" => id}) do
    with {:ok, pull_request} <- fetch_pull_request(conn, id),
         :ok <- authorize(conn, :pull_request, :merge) do
      PullRequestActions.queue_merge(conn, pull_request)
    else
      {:error, :not_found} -> Response.pull_request_not_found(conn)
      {:error, :forbidden} -> Response.forbidden(conn)
    end
  end

  def cancel_merge_candidate(conn, %{"id" => id}) do
    with {:ok, candidate} <- fetch_merge_candidate(conn, id),
         :ok <- authorize(conn, :merge_candidate, :cancel) do
      PullRequestActions.cancel_merge_candidate(conn, candidate)
    else
      {:error, :not_found} -> Response.merge_candidate_not_found(conn)
      {:error, :forbidden} -> Response.forbidden(conn)
    end
  end

  def import_github_repo(conn, params) do
    with :ok <- authorize(conn, :repository, :create) do
      RepoActions.import_github_repo(conn, params)
    else
      {:error, :forbidden} -> Response.forbidden(conn)
    end
  end

  def change_readiness(conn, %{"id" => id}) do
    json(conn, %{data: Enum.map(ReadModels.change_readiness(id), &Response.serialize/1)})
  end

  def agent_sessions(conn, %{"id" => id} = params) do
    Response.paged(conn, ReadModels.agent_sessions(id), params)
  end

  def agent_policies(conn, %{"id" => id} = params) do
    Response.paged(conn, ReadModels.agent_policies(id), params)
  end

  def import_repo(conn, params) do
    with :ok <- authorize(conn, :repository, :import) do
      RepoActions.import_repo(conn, params)
    else
      {:error, :forbidden} -> Response.forbidden(conn)
    end
  end

  def simulate_merge(conn, params), do: MergeActions.simulate(conn, params)

  def analysis_callback(conn, %{"id" => id} = params) do
    case Repo.get(AnalysisRun, id) do
      nil -> Response.analysis_run_not_found(conn)
      analysis_run -> AnalysisActions.callback(conn, analysis_run, params)
    end
  end

  def webhook(conn, params), do: WebhookActions.ingest(conn, params)

  defp fetch_repo(conn, id) do
    case Forge.get_repository_for_org(conn.assigns.current_organization.id, id) do
      nil -> {:error, :not_found}
      repository -> {:ok, repository}
    end
  end

  defp authorize(conn, resource, action) do
    if RBAC.allowed?(conn.assigns.current_membership, resource, action) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp trust_payload(nil), do: nil

  defp trust_payload(signal) do
    %{
      source: signal.source,
      signal_type: signal.signal_type,
      score: signal.score,
      confidence: signal.confidence,
      payload: signal.payload
    }
  end

  defp fetch_pull_request(conn, id) do
    case Forge.get_pull_request_for_org(conn.assigns.current_organization.id, id) do
      nil -> {:error, :not_found}
      pull_request -> {:ok, pull_request}
    end
  end

  defp fetch_merge_candidate(conn, id) do
    current_organization_id = conn.assigns.current_organization.id

    candidate =
      MergeCandidate
      |> Repo.get(id)
      |> Repo.preload(:repository)

    case candidate do
      %MergeCandidate{repository: %{organization_id: ^current_organization_id}} ->
        {:ok, candidate}

      _ ->
        {:error, :not_found}
    end
  end

  defp parse_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp parse_positive_integer(value) do
    case Integer.parse(to_string(value)) do
      {number, ""} when number > 0 -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end
end
