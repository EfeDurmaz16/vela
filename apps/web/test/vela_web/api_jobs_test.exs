defmodule VelaWeb.ApiJobsTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Forge, Merge}
  alias VelaWeb.Plugs.ApiAuth

  test "repo import endpoint enqueues a real Oban import job", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "Jobs Org", slug: "jobs-org"})
    session = auth_session_for_org!(org, "jobs")

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
      |> init_test_session(%{ApiAuth.session_key() => session})
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

  test "repo import endpoint replays the first response for the same idempotency key and request",
       %{
         conn: conn
       } do
    {:ok, org} = Accounts.create_organization(%{name: "Idempotent Org", slug: "idempotent-org"})
    session = auth_session_for_org!(org, "idempotent")

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

    conn =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put_req_header("idempotency-key", "idem-import-1")

    first =
      conn
      |> post(~p"/api/v1/repos/#{repo.id}/import", %{owner: "vela", repo: "core"})
      |> json_response(202)

    second =
      conn
      |> recycle()
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put_req_header("idempotency-key", "idem-import-1")
      |> post(~p"/api/v1/repos/#{repo.id}/import", %{owner: "vela", repo: "core"})
      |> json_response(202)

    assert second == first
    assert length(Oban.Job |> Vela.Repo.all()) == 1
  end

  test "repo import endpoint rejects idempotency key reuse with a different request", %{
    conn: conn
  } do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Idempotent Conflict Org",
        slug: "idempotent-conflict-org"
      })

    session = auth_session_for_org!(org, "idempotent-conflict")

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

    conn =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put_req_header("idempotency-key", "idem-import-conflict")

    conn
    |> post(~p"/api/v1/repos/#{repo.id}/import", %{owner: "vela", repo: "core"})
    |> json_response(202)

    response =
      conn
      |> recycle()
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put_req_header("idempotency-key", "idem-import-conflict")
      |> post(~p"/api/v1/repos/#{repo.id}/import", %{owner: "vela", repo: "other"})
      |> json_response(409)

    assert %{"error" => %{"code" => "idempotency_key_reused"}} = response
  end

  test "merge simulation endpoint enqueues a real Oban merge job", %{conn: conn} do
    {:ok, org} = Accounts.create_organization(%{name: "Merge Org", slug: "merge-org"})
    session = auth_session_for_org!(org, "merge")
    %{candidate: candidate} = merge_candidate_fixture!(org)

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
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

  test "merge simulation endpoint replays the first response for the same idempotency key", %{
    conn: conn
  } do
    {:ok, org} = Accounts.create_organization(%{name: "Merge Idem Org", slug: "merge-idem-org"})
    session = auth_session_for_org!(org, "merge-idem")
    %{candidate: candidate} = merge_candidate_fixture!(org)

    conn =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put_req_header("idempotency-key", "idem-merge-1")

    first =
      conn
      |> post(~p"/api/v1/merge-candidates/#{candidate.id}/simulate", %{})
      |> json_response(202)

    second =
      conn
      |> recycle()
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> put_req_header("idempotency-key", "idem-merge-1")
      |> post(~p"/api/v1/merge-candidates/#{candidate.id}/simulate", %{})
      |> json_response(202)

    assert second == first
    assert length(Oban.Job |> Vela.Repo.all()) == 1
  end

  defp merge_candidate_fixture!(org) do
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
        slug: "core-#{System.unique_integer([:positive])}",
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

    %{actor: actor, repo: repo, pull_request: pr, candidate: candidate}
  end

  defp auth_session_for_org!(org, suffix) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "api-jobs-#{suffix}@example.com",
        name: "API Jobs #{suffix}",
        workos_user_id: "workos_api_jobs_#{suffix}"
      })

    {:ok, membership} =
      Accounts.create_membership(%{
        user_id: user.id,
        organization_id: org.id,
        role: "admin"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        created_by_user_id: user.id,
        type: "human",
        display_name: user.name,
        trust_level: "trusted",
        external_ref: "workos:#{user.workos_user_id}"
      })

    %{
      "user_id" => user.id,
      "organization_id" => org.id,
      "membership_id" => membership.id,
      "actor_id" => actor.id
    }
  end
end
