defmodule Vela.Jobs.RepoSyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 5

  alias Vela.Outbox.OutboxEvent

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with :ok <-
           Vela.Jobs.WorkerGuards.require_keys(
             args,
             ~w(kind organization_id repository_id provider)
           ),
         :ok <- sync_repository(args) do
      :ok
    end
  end

  defp sync_repository(%{"provider" => "github", "pull_request_number" => number} = args) do
    repository = Vela.Repo.get!(Vela.Forge.Repository, Map.fetch!(args, "repository_id"))
    [owner, repo] = String.split(repository.full_name || "", "/", parts: 2)
    config = Application.get_env(:vela, :github, [])

    attrs = %{
      owner: owner,
      repo: repo,
      number: number,
      token: Keyword.get(config, :token),
      transport: Keyword.get(config, :transport)
    }

    with {:ok, imported} <- Vela.Git.GitHubClient.fetch_pull_request(attrs),
         {:ok, changed_files} <- Vela.Git.GitHubClient.list_pull_request_files(attrs),
         {:ok, reviews} <- Vela.Git.GitHubClient.list_pull_request_reviews(attrs),
         {:ok, check_runs} <-
           Vela.Git.GitHubClient.list_check_runs(Map.put(attrs, :sha, imported.head_sha)),
         {:ok, pr} <-
           Vela.Forge.upsert_pull_request_by_provider(
             repository.id,
             "github",
             imported.external_number,
             %{
               author_actor_id: Map.get(args, "actor_id"),
               title: imported.title,
               description: imported.description,
               source_branch: imported.source_branch,
               target_branch: imported.target_branch,
               head_sha: imported.head_sha,
               base_sha: imported.base_sha,
               status: imported.status,
               provider: "github",
               external_id: to_string(imported.external_id),
               external_number: imported.external_number,
               html_url: imported.html_url
             }
           ),
         :ok <- import_pull_request_files(pr.id, changed_files),
         :ok <- import_pull_request_reviews(pr.id, reviews, Map.get(args, "actor_id")),
         :ok <- import_check_runs(repository.id, pr.id, check_runs),
         {:ok, _candidate} <-
           Vela.Merge.upsert_merge_candidate_by_pull_request(pr.id, %{
             repository_id: repository.id,
             base_sha: imported.base_sha,
             head_sha: imported.head_sha,
             target_branch: imported.target_branch,
             status: "pending"
           }),
         {:ok, _score} <- seed_readiness(repository, pr),
         :ok <- record_pr_synced(repository, pr, Map.get(args, "actor_id")) do
      :ok
    end
  end

  defp sync_repository(%{"provider" => provider}), do: {:error, {:unsupported_provider, provider}}
  defp sync_repository(_args), do: {:error, :missing_provider}

  defp import_pull_request_files(pull_request_id, files) do
    Enum.reduce_while(files, :ok, fn file, :ok ->
      case Vela.Forge.upsert_pull_request_file(pull_request_id, file) do
        {:ok, _file} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp import_pull_request_reviews(_pull_request_id, _reviews, nil), do: :ok

  defp import_pull_request_reviews(pull_request_id, reviews, actor_id) do
    Enum.reduce_while(reviews, :ok, fn review, :ok ->
      case Vela.Forge.upsert_review_by_provider(
             pull_request_id,
             "github",
             review.external_id,
             Map.put(review, :actor_id, actor_id)
           ) do
        {:ok, _review} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp import_check_runs(repository_id, pull_request_id, check_runs) do
    Enum.reduce_while(check_runs, :ok, fn check_run, :ok ->
      case Vela.Forge.upsert_check_run(repository_id, pull_request_id, check_run) do
        {:ok, _check_run} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp seed_readiness(repository, pr) do
    dimensions = %{
      "repository_trust" => repository_trust(repository),
      "change_risk" => change_risk(pr),
      "test_evidence" => 50,
      "security" => 70,
      "performance" => 70,
      "agent_provenance" => 60,
      "launch_readiness" => 65
    }

    readiness = Vela.Maestro.compute_readiness(%{dimensions: dimensions, confidence: "medium"})

    Vela.Maestro.create_readiness_score(%{
      organization_id: repository.organization_id,
      repository_id: repository.id,
      score: readiness.score,
      verdict: readiness.verdict,
      confidence: readiness.confidence,
      dimensions: readiness.dimensions,
      explanation: "Seeded from GitHub PR sync until full analysis completes.",
      evidence_refs: [],
      input_refs: Vela.Maestro.ReadinessInputs.collect_for_pull_request(pr.id)
    })
  end

  defp record_pr_synced(repository, pr, actor_id) do
    payload = %{
      pull_request_id: pr.id,
      external_number: pr.external_number,
      head_sha: pr.head_sha,
      base_sha: pr.base_sha
    }

    {:ok, _event} =
      Vela.Evidence.append_event(%{
        organization_id: repository.organization_id,
        repository_id: repository.id,
        actor_id: actor_id,
        event_type: "pr.synced",
        resource_type: "pull_request",
        resource_id: pr.id,
        payload: payload
      })

    %OutboxEvent{}
    |> OutboxEvent.changeset(%{
      organization_id: repository.organization_id,
      repository_id: repository.id,
      event_type: "pr.synced",
      payload: payload,
      status: "pending"
    })
    |> Vela.Repo.insert!()

    :ok
  end

  defp repository_trust(%{health_status: "healthy"}), do: 80
  defp repository_trust(%{health_status: "degraded"}), do: 60
  defp repository_trust(%{health_status: "failing"}), do: 35
  defp repository_trust(_repository), do: 50

  defp change_risk(%{status: "draft"}), do: 60
  defp change_risk(%{status: "ready_for_review"}), do: 75
  defp change_risk(_pr), do: 65
end
