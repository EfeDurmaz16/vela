defmodule Vela.Forge.PullRequestsTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Forge, Maestro, Merge}
  alias Vela.Forge.PullRequests

  test "get_for_route! scopes by organization slug, repository slug, and pull request id" do
    %{org: org, pull_request: pull_request, repo: repo} = pr_fixture!("route-a")
    %{pull_request: other_pull_request} = pr_fixture!("route-b")

    found = PullRequests.get_for_route!(org.slug, repo.slug, pull_request.id)

    assert found.id == pull_request.id
    assert found.repository.organization.slug == org.slug

    assert_raise Ecto.NoResultsError, fn ->
      PullRequests.get_for_route!(org.slug, repo.slug, other_pull_request.id)
    end
  end

  test "get_for_route! preloads cockpit associations" do
    %{org: org, pull_request: pull_request, repo: repo} = pr_fixture!("preload")

    found = PullRequests.get_for_route!(org.slug, repo.slug, pull_request.id)

    assert %Vela.Actors.Actor{} = found.author_actor
    assert [%Vela.Forge.Review{}] = found.reviews
    assert [%Vela.Maestro.LaunchReadinessScore{}] = found.readiness_scores
    assert [%Vela.Merge.MergeCandidate{}] = found.merge_candidates
    assert %Vela.Accounts.Organization{} = found.repository.organization
  end

  defp pr_fixture!(suffix) do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "PR Route #{suffix}",
        slug: "pr-route-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "PR Actor #{suffix}",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "core",
        slug: "core-#{suffix}",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    {:ok, pull_request} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: actor.id,
        title: "Change #{suffix}",
        source_branch: "feature/#{suffix}",
        target_branch: "main",
        head_sha: "head-#{suffix}",
        base_sha: "base-#{suffix}",
        status: "ready_for_review"
      })

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: actor.id,
        status: "approve",
        summary: "Ship it"
      })

    {:ok, analysis_run} =
      Maestro.create_analysis_run(%{
        organization_id: org.id,
        repository_id: repo.id,
        pull_request_id: pull_request.id,
        commit_sha: pull_request.head_sha,
        status: "completed",
        summary: "Ready"
      })

    {:ok, _score} =
      Maestro.create_launch_readiness_score(%{
        analysis_run_id: analysis_run.id,
        pull_request_id: pull_request.id,
        overall_score: 90,
        verdict: "ship",
        confidence: "high",
        behavioral_score: 90,
        correctness_score: 90,
        security_score: 90,
        performance_score: 90,
        ux_score: 90,
        test_evidence_score: 90,
        rollback_score: 90,
        agent_provenance_score: 90,
        explanation: "Ready",
        blocking_findings: [],
        required_actions: []
      })

    {:ok, _candidate} =
      Merge.create_merge_candidate(%{
        repository_id: repo.id,
        pull_request_id: pull_request.id,
        base_sha: pull_request.base_sha,
        head_sha: pull_request.head_sha,
        status: "pending"
      })

    %{actor: actor, org: org, pull_request: pull_request, repo: repo}
  end
end
