defmodule Vela.Jobs.RepoSyncWorker do
  use Oban.Worker, queue: :sync, max_attempts: 5

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

    with {:ok, imported} <-
           Vela.Git.GitHubClient.fetch_pull_request(%{
             owner: owner,
             repo: repo,
             number: number,
             token: Keyword.get(config, :token),
             transport: Keyword.get(config, :transport)
           }),
         {:ok, _pr} <-
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
           ) do
      :ok
    end
  end

  defp sync_repository(%{"provider" => provider}), do: {:error, {:unsupported_provider, provider}}
  defp sync_repository(_args), do: {:error, :missing_provider}
end
