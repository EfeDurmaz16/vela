defmodule Vela.JobsRepoSyncTest do
  use Vela.DataCase, async: false

  alias Vela.{Accounts, Actors, Forge}
  alias Vela.Jobs.RepoSyncWorker

  test "repo sync worker imports a GitHub pull request into local state" do
    previous = Application.get_env(:vela, :github)

    Application.put_env(:vela, :github,
      token: "ghp_test",
      transport: fn req ->
        assert req.url.path == "/repos/vela/core/pulls/17"

        {:ok,
         %{
           status: 200,
           body: %{
             "id" => 987,
             "number" => 17,
             "title" => "Improve sync",
             "body" => "Adds sync",
             "html_url" => "https://github.com/vela/core/pull/17",
             "state" => "open",
             "draft" => false,
             "head" => %{"ref" => "feature/sync", "sha" => "headsha"},
             "base" => %{"ref" => "main", "sha" => "basesha"},
             "user" => %{"login" => "octocat"}
           }
         }}
      end
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :github, previous),
        else: Application.delete_env(:vela, :github)
    end)

    {:ok, org} = Accounts.create_organization(%{name: "Sync Org", slug: "sync-org"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "integration",
        display_name: "GitHub",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low",
        provider: "github",
        full_name: "vela/core",
        import_status: "imported"
      })

    assert :ok =
             RepoSyncWorker.perform(%Oban.Job{
               args: %{
                 "kind" => "repo_sync",
                 "organization_id" => org.id,
                 "repository_id" => repo.id,
                 "actor_id" => actor.id,
                 "provider" => "github",
                 "pull_request_number" => 17
               }
             })

    [pr] = Forge.list_pull_requests()
    assert pr.repository_id == repo.id
    assert pr.provider == "github"
    assert pr.external_id == "987"
    assert pr.external_number == 17
    assert pr.title == "Improve sync"
    assert pr.source_branch == "feature/sync"
    assert pr.target_branch == "main"
    assert pr.status == "ready_for_review"
  end
end
