defmodule Vela.Jobs.RepoImportWorker do
  use Oban.Worker, queue: :imports, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    with :ok <-
           Vela.Jobs.WorkerGuards.require_keys(
             args,
             ~w(kind organization_id repository_id provider)
           ),
         :ok <- import_repository(args) do
      :ok
    end
  end

  defp import_repository(%{"provider" => "github"} = args) do
    config = Application.get_env(:vela, :github, [])

    attrs = %{
      owner: Map.fetch!(args, "owner"),
      repo: Map.fetch!(args, "repo"),
      token: Keyword.get(config, :token),
      transport: Keyword.get(config, :transport)
    }

    repository = Vela.Repo.get!(Vela.Forge.Repository, Map.fetch!(args, "repository_id"))

    case Vela.Git.GitHubClient.import_repository(attrs) do
      {:ok, imported} ->
        with {:ok, _repository} <-
               Vela.Forge.update_repository(repository, %{
                 name: imported.name,
                 slug: imported.slug,
                 visibility: imported.visibility,
                 default_branch: imported.default_branch,
                 description: imported.full_name,
                 provider: imported.provider,
                 external_id: to_string(imported.external_id),
                 full_name: imported.full_name,
                 html_url: imported.html_url,
                 import_status: "imported",
                 imported_at: DateTime.utc_now(:second),
                 last_import_error: nil,
                 health_status: "healthy"
               }) do
          :ok
        end

      {:error, reason} = error ->
        {:ok, _repository} =
          Vela.Forge.update_repository(repository, %{
            import_status: "failed",
            last_import_error: inspect(reason),
            health_status: "failing"
          })

        error
    end
  end

  defp import_repository(%{"provider" => provider}),
    do: {:error, {:unsupported_provider, provider}}

  defp import_repository(_args), do: {:error, :missing_provider}
end
