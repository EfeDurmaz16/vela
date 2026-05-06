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

    result =
      with {:ok, imported} <- Vela.Git.GitHubClient.import_repository(attrs),
           {:ok, branches} <- Vela.Git.GitHubClient.list_branches(attrs) do
        {:ok, imported, branches}
      end

    case result do
      {:ok, imported, branches} ->
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
               }),
             :ok <- import_branches(repository.id, branches) do
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

  defp import_branches(repository_id, branches) do
    Enum.reduce_while(branches, :ok, fn branch, :ok ->
      case Vela.Forge.upsert_branch(repository_id, branch) do
        {:ok, _branch} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end
end
