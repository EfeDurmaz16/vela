defmodule VelaWeb.Api.V1.RepoActions do
  @moduledoc """
  Repository mutation actions for the v1 JSON API.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Vela.{Forge, Jobs, Repo}
  alias VelaWeb.Api.V1.IdempotentMutation
  alias VelaWeb.Api.V1.MutationAudit
  alias VelaWeb.Api.V1.Response

  def import_github_repo(conn, %{"owner" => owner, "repo" => repo_name} = params) do
    provider = Map.get(params, "provider", "github")

    with :ok <- ensure_github_provider(provider),
         {:ok, repository} <- upsert_github_import_placeholder(conn, owner, repo_name) do
      IdempotentMutation.respond(conn, repository.organization_id, fn ->
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

            MutationAudit.record_job_accepted!(conn, %{
              organization_id: repository.organization_id,
              repository_id: repository.id,
              event_type: "repo.import_queued",
              resource_type: "repository",
              resource_id: repository.id,
              job: job
            })

            job
          end)

        {202, %{data: %{repository: Response.serialize(repository), job: job_payload(job)}}}
      end)
    else
      {:error, :unsupported_provider} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "unsupported_provider"}})

      {:error, changeset} ->
        Response.validation_error(conn, changeset)
    end
  end

  def import_repo(conn, %{"id" => id}) do
    repository = Repo.get!(Vela.Forge.Repository, id)

    IdempotentMutation.respond(conn, repository.organization_id, fn ->
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

          MutationAudit.record_job_accepted!(conn, %{
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

  defp job_payload(%Oban.Job{} = job) do
    %{id: job.id, status: "queued", kind: job.args["kind"], queue: job.queue}
  end
end
