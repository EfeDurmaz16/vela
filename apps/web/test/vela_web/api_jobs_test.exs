defmodule VelaWeb.ApiJobsTest do
  use VelaWeb.ConnCase, async: true

  alias Vela.{Accounts, Actors, Forge, Merge}

  test "repo import endpoint enqueues a real Oban import job", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "Jobs Org", slug: "jobs-org"})

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    response =
      conn
      |> post(~p"/api/v1/repos/#{repo.id}/import", %{owner: "vela", repo: "core"})
      |> json_response(202)

    assert %{
             "data" => %{
               "job" => %{"id" => job_id, "kind" => "repo_import", "status" => "queued"}
             }
           } = response

    assert %Oban.Job{args: %{"repository_id" => repo_id, "organization_id" => org_id}} =
             Vela.Repo.get!(Oban.Job, job_id)

    assert repo_id == repo.id
    assert org_id == org.id
  end

  test "merge simulation endpoint enqueues a real Oban merge job", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "Merge Org", slug: "merge-org"})

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Reviewer",
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
        risk_level: "low"
      })

    {:ok, pr} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: actor.id,
        title: "Change",
        source_branch: "feature",
        target_branch: "main",
        head_sha: "head",
        base_sha: "base",
        status: "ready_for_review"
      })

    {:ok, candidate} =
      Merge.create_merge_candidate(%{
        repository_id: repo.id,
        pull_request_id: pr.id,
        base_sha: "base",
        head_sha: "head",
        status: "pending"
      })

    response =
      conn
      |> post(~p"/api/v1/merge-candidates/#{candidate.id}/simulate", %{})
      |> json_response(202)

    assert %{
             "data" => %{
               "job" => %{"id" => job_id, "kind" => "merge_simulation", "status" => "queued"}
             }
           } = response

    assert %Oban.Job{args: %{"merge_candidate_id" => candidate_id}} =
             Vela.Repo.get!(Oban.Job, job_id)

    assert candidate_id == candidate.id
  end
end
