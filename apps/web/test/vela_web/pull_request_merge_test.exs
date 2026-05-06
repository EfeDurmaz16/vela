defmodule VelaWeb.PullRequestMergeTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Forge, Maestro, Merge, Repo}
  alias VelaWeb.Plugs.ApiAuth

  test "authenticated users can queue a reviewed pull request for merge", %{conn: conn} do
    %{org: org, session: session, pull_request: pr, reviewer: reviewer, candidate: candidate} =
      pr_fixture!("passing")

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pr.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ship it"
      })

    {:ok, _score} =
      Maestro.create_readiness_score(%{
        organization_id: org.id,
        repository_id: pr.repository_id,
        score: 91,
        verdict: "ship",
        confidence: "high",
        dimensions: readiness_dimensions(91),
        explanation: "Ready to merge"
      })

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/merge", %{})
      |> json_response(202)

    assert %{
             "data" => %{
               "pull_request_id" => pull_request_id,
               "merge_candidate" => %{"id" => candidate_id, "status" => "queued"}
             }
           } = response

    assert pull_request_id == pr.id
    assert candidate_id == candidate.id
    assert %{status: "queued"} = Repo.get!(Merge.MergeCandidate, candidate.id)

    assert [%{event_type: "merge.queued", resource_id: ^candidate_id, organization_id: org_id}] =
             Vela.Evidence.list_repository_events(pr.repository_id, 5)

    assert org_id == org.id

    assert [%{event_type: "merge.queued", repository_id: repository_id}] =
             Vela.Outbox.OutboxEvent |> Repo.all()

    assert repository_id == pr.repository_id
  end

  test "maintainer role can queue a reviewed pull request for merge", %{conn: conn} do
    %{org: org, session: session, pull_request: pr, reviewer: reviewer, candidate: candidate} =
      pr_fixture!("maintainer", "maintainer")

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pr.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ship it"
      })

    {:ok, _score} =
      Maestro.create_readiness_score(%{
        organization_id: org.id,
        repository_id: pr.repository_id,
        score: 91,
        verdict: "ship",
        confidence: "high",
        dimensions: readiness_dimensions(91),
        explanation: "Ready to merge"
      })

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/merge", %{})
      |> json_response(202)

    assert %{"data" => %{"merge_candidate" => %{"id" => candidate_id, "status" => "queued"}}} =
             response

    assert candidate_id == candidate.id
  end

  test "reviewer role cannot queue merge even when gates pass", %{conn: conn} do
    %{org: org, session: session, pull_request: pr, reviewer: reviewer, candidate: candidate} =
      pr_fixture!("reviewer-denied", "reviewer")

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pr.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ship it"
      })

    {:ok, _score} =
      Maestro.create_readiness_score(%{
        organization_id: org.id,
        repository_id: pr.repository_id,
        score: 91,
        verdict: "ship",
        confidence: "high",
        dimensions: readiness_dimensions(91),
        explanation: "Ready to merge"
      })

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/merge", %{})
      |> json_response(403)

    assert response == %{"error" => %{"code" => "forbidden"}}
    assert %{status: "pending"} = Repo.get!(Merge.MergeCandidate, candidate.id)
  end

  test "merge queue rejects pull requests that have not passed review gates", %{conn: conn} do
    %{session: session, pull_request: pr} = pr_fixture!("missing-approval")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/merge", %{})
      |> json_response(422)

    assert %{"error" => %{"code" => "merge_gate_failed", "reason" => "missing_approval"}} =
             response
  end

  test "merge queue rejects pull requests outside the authenticated tenant", %{conn: conn} do
    %{session: session} = pr_fixture!("tenant-a")
    %{pull_request: pr} = pr_fixture!("tenant-b")

    response =
      conn
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> post(~p"/api/v1/pull-requests/#{pr.id}/merge", %{})
      |> json_response(404)

    assert %{"error" => %{"code" => "pull_request_not_found"}} = response
  end

  defp pr_fixture!(suffix, role \\ "admin") do
    unique = System.unique_integer([:positive])

    {:ok, org} =
      Accounts.create_organization(%{
        name: "PR Merge #{suffix}",
        slug: "pr-merge-#{suffix}-#{unique}"
      })

    session = auth_session_for_org!(org, suffix, unique, role)

    {:ok, author} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Author",
        trust_level: "trusted"
      })

    {:ok, reviewer} =
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
        slug: "core-#{unique}",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    {:ok, pr} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: author.id,
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

    %{
      org: org,
      repo: repo,
      pull_request: pr,
      session: session,
      reviewer: reviewer,
      candidate: candidate
    }
  end

  defp auth_session_for_org!(org, suffix, unique, role) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "pr-merge-#{suffix}-#{unique}@example.com",
        name: "PR Merge #{suffix}",
        workos_user_id: "workos_pr_merge_#{suffix}_#{unique}"
      })

    {:ok, membership} =
      Accounts.create_membership(%{user_id: user.id, organization_id: org.id, role: role})

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

  defp readiness_dimensions(score) do
    %{
      "repository_trust" => score,
      "change_risk" => score,
      "test_evidence" => score,
      "security" => score,
      "performance" => score,
      "agent_provenance" => score,
      "launch_readiness" => score
    }
  end
end
