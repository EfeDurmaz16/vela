defmodule Vela.JobsRepoSyncTest do
  use Vela.DataCase, async: false

  alias Vela.{Accounts, Actors, Forge, Repo}
  alias Vela.Jobs.RepoSyncWorker

  test "repo sync worker imports a GitHub pull request into local state" do
    previous = Application.get_env(:vela, :github)

    Application.put_env(:vela, :github,
      token: "ghp_test",
      transport: fn req ->
        case req.url.path do
          "/repos/vela/core/pulls/17" ->
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

          "/repos/vela/core/pulls/17/files" ->
            {:ok,
             %{
               status: 200,
               body: [
                 %{
                   "filename" => "apps/web/lib/core.ex",
                   "status" => "modified",
                   "additions" => 12,
                   "deletions" => 3,
                   "changes" => 15,
                   "patch" => "@@ patch",
                   "blob_url" => "https://github.test/blob/core.ex",
                   "raw_url" => "https://github.test/raw/core.ex"
                 },
                 %{
                   "filename" => "apps/web/lib/new_name.ex",
                   "previous_filename" => "apps/web/lib/old_name.ex",
                   "status" => "renamed",
                   "additions" => 4,
                   "deletions" => 1,
                   "changes" => 5
                 },
                 %{
                   "filename" => "apps/web/lib/deleted.ex",
                   "status" => "removed",
                   "additions" => 0,
                   "deletions" => 8,
                   "changes" => 8
                 }
               ]
             }}

          "/repos/vela/core/pulls/17/reviews" ->
            {:ok,
             %{
               status: 200,
               body: [
                 %{
                   "id" => 9001,
                   "state" => "APPROVED",
                   "body" => "Ship it",
                   "submitted_at" => "2026-05-06T08:00:00Z",
                   "user" => %{"login" => "reviewer-a"}
                 },
                 %{
                   "id" => 9002,
                   "state" => "CHANGES_REQUESTED",
                   "body" => "Needs tests",
                   "submitted_at" => "2026-05-06T08:05:00Z",
                   "user" => %{"login" => "reviewer-b"}
                 },
                 %{
                   "id" => 9003,
                   "state" => "COMMENTED",
                   "body" => "Question",
                   "submitted_at" => "2026-05-06T08:10:00Z",
                   "user" => %{"login" => "reviewer-c"}
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

    files =
      Vela.Forge.PullRequestFile
      |> where([file], file.pull_request_id == ^pr.id)
      |> order_by([file], asc: file.path)
      |> Repo.all()

    assert [
             %{
               path: "apps/web/lib/core.ex",
               previous_path: nil,
               status: "modified",
               additions: 12,
               deletions: 3,
               changes: 15,
               patch: "@@ patch",
               blob_url: "https://github.test/blob/core.ex",
               raw_url: "https://github.test/raw/core.ex"
             },
             %{
               path: "apps/web/lib/deleted.ex",
               previous_path: nil,
               status: "removed",
               additions: 0,
               deletions: 8,
               changes: 8
             },
             %{
               path: "apps/web/lib/new_name.ex",
               previous_path: "apps/web/lib/old_name.ex",
               status: "renamed",
               additions: 4,
               deletions: 1,
               changes: 5
             }
           ] = files

    reviews =
      Vela.Forge.Review
      |> where([review], review.pull_request_id == ^pr.id)
      |> order_by([review], asc: review.external_id)
      |> Repo.all()

    assert [
             %{
               provider: "github",
               external_id: "9001",
               external_author_login: "reviewer-a",
               status: "approve",
               summary: "Ship it",
               submitted_at: ~U[2026-05-06 08:00:00Z]
             },
             %{
               provider: "github",
               external_id: "9002",
               external_author_login: "reviewer-b",
               status: "request_changes",
               summary: "Needs tests",
               submitted_at: ~U[2026-05-06 08:05:00Z]
             },
             %{
               provider: "github",
               external_id: "9003",
               external_author_login: "reviewer-c",
               status: "comment",
               summary: "Question",
               submitted_at: ~U[2026-05-06 08:10:00Z]
             }
           ] = reviews

    assert {:ok, _review} =
             Forge.upsert_review_by_provider(pr.id, "github", 9001, %{
               actor_id: actor.id,
               status: "request_changes",
               summary: "Latest state wins",
               external_author_login: "reviewer-a",
               submitted_at: ~U[2026-05-06 08:15:00Z]
             })

    assert Repo.aggregate(Vela.Forge.Review, :count) == 3

    assert %{
             status: "request_changes",
             summary: "Latest state wins",
             submitted_at: ~U[2026-05-06 08:15:00Z]
           } = Repo.get_by!(Vela.Forge.Review, pull_request_id: pr.id, external_id: "9001")

    [candidate] = Vela.Merge.MergeCandidate |> Repo.all()
    assert candidate.repository_id == repo.id
    assert candidate.pull_request_id == pr.id
    assert candidate.base_sha == "basesha"
    assert candidate.head_sha == "headsha"
    assert candidate.status == "pending"

    [score] = Vela.Maestro.ReadinessScore |> Repo.all()
    assert score.repository_id == repo.id
    assert score.score >= 0
    assert score.verdict in ["ship", "wait", "block"]

    assert [%{event_type: "pr.synced", resource_id: pr_id}] =
             Vela.Evidence.list_repository_events(repo.id, 5)

    assert pr_id == pr.id
  end
end
