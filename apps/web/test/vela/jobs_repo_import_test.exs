defmodule Vela.JobsRepoImportTest do
  use Vela.DataCase, async: false

  alias Vela.{Accounts, Forge, Repo}
  alias Vela.Jobs.RepoImportWorker

  test "repo import worker imports GitHub repository metadata into the repository row" do
    previous = Application.get_env(:vela, :github)

    Application.put_env(:vela, :github,
      token: "ghp_test",
      transport: fn req ->
        assert req.url.path == "/repos/vela/core"

        {:ok,
         %{
           status: 200,
           body: %{
             "id" => 42,
             "name" => "core",
             "full_name" => "vela/core",
             "private" => false,
             "default_branch" => "trunk"
           }
         }}
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
  end
end
