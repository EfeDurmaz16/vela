defmodule Vela.JobsRepoImportTest do
  use Vela.DataCase, async: false

  alias Vela.{Accounts, Forge, Repo}
  alias Vela.Jobs.RepoImportWorker

  test "repo import worker imports GitHub repository metadata into the repository row" do
    previous = Application.get_env(:vela, :github)

    Application.put_env(:vela, :github,
      token: "ghp_test",
      transport: fn req ->
        case req.url.path do
          "/repos/vela/core" ->
            {:ok,
             %{
               status: 200,
               body: %{
                 "id" => 42,
                 "name" => "core",
                 "full_name" => "vela/core",
                 "html_url" => "https://github.com/vela/core",
                 "private" => false,
                 "default_branch" => "trunk"
               }
             }}

          "/repos/vela/core/branches" ->
            {:ok,
             %{
               status: 200,
               body: [
                 %{
                   "name" => "trunk",
                   "commit" => %{"sha" => "sha_trunk"},
                   "protected" => true
                 },
                 %{
                   "name" => "feature/demo",
                   "commit" => %{"sha" => "sha_feature"},
                   "protected" => false
                 }
               ]
             }}
        end
      end
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :github, previous),
        else: Application.delete_env(:vela, :github)
    end)

    {:ok, org} = Accounts.create_organization(%{name: "Import Org", slug: "import-org"})

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "placeholder",
        slug: "placeholder",
        visibility: "private",
        default_branch: "main",
        health_status: "unknown",
        risk_level: "medium"
      })

    assert :ok =
             RepoImportWorker.perform(%Oban.Job{
               args: %{
                 "kind" => "repo_import",
                 "organization_id" => org.id,
                 "repository_id" => repo.id,
                 "provider" => "github",
                 "owner" => "vela",
                 "repo" => "core"
               }
             })

    updated = Repo.get!(Vela.Forge.Repository, repo.id)
    assert updated.name == "core"
    assert updated.slug == "core"
    assert updated.visibility == "public"
    assert updated.default_branch == "trunk"
    assert updated.provider == "github"
    assert updated.external_id == "42"
    assert updated.full_name == "vela/core"
    assert updated.html_url == "https://github.com/vela/core"
    assert updated.import_status == "imported"
    assert %DateTime{} = updated.imported_at
    assert updated.last_import_error == nil

    branches =
      Vela.Forge.Branch
      |> where([branch], branch.repository_id == ^repo.id)
      |> order_by([branch], asc: branch.name)
      |> Repo.all()

    assert [
             %{name: "feature/demo", current_sha: "sha_feature", protected: false},
             %{name: "trunk", current_sha: "sha_trunk", protected: true}
           ] = branches
  end

  test "repo import worker marks failed imports without losing the repository row" do
    previous = Application.get_env(:vela, :github)

    Application.put_env(:vela, :github,
      token: "ghp_test",
      transport: fn _req ->
        {:ok, %{status: 404, body: %{"message" => "Not Found"}}}
      end
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :github, previous),
        else: Application.delete_env(:vela, :github)
    end)

    {:ok, org} = Accounts.create_organization(%{name: "Import Fail Org", slug: "import-fail-org"})

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "placeholder",
        slug: "placeholder",
        visibility: "private",
        default_branch: "main",
        health_status: "unknown",
        risk_level: "medium",
        import_status: "pending"
      })

    assert {:error, {:github_error, 404, %{"message" => "Not Found"}}} =
             RepoImportWorker.perform(%Oban.Job{
               args: %{
                 "kind" => "repo_import",
                 "organization_id" => org.id,
                 "repository_id" => repo.id,
                 "provider" => "github",
                 "owner" => "vela",
                 "repo" => "missing"
               }
             })

    updated = Repo.get!(Vela.Forge.Repository, repo.id)
    assert updated.import_status == "failed"
    assert updated.health_status == "failing"
    assert updated.last_import_error =~ "github_error"
  end
end
