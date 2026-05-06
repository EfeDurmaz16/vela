defmodule Vela.Merge.GatesTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Forge, Maestro}
  alias Vela.Merge.Gates

  test "review_gate requires approval" do
    %{pull_request: pull_request, reviewer: reviewer} = pr_fixture!("approval")

    assert {:error, :missing_approval} = Gates.review_gate(pull_request.id)

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ship it"
      })

    assert :ok = Gates.review_gate(pull_request.id)
  end

  test "review_gate blocks request changes and block reviews" do
    %{pull_request: pull_request, reviewer: reviewer} = pr_fixture!("blocking")

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: reviewer.id,
        status: "block",
        summary: "Unsafe"
      })

    assert {:error, :blocking_review} = Gates.review_gate(pull_request.id)
  end

  test "readiness_gate requires latest repository readiness to ship" do
    %{org: org, repo: repo} = pr_fixture!("readiness")

    assert {:error, :missing_readiness} = Gates.readiness_gate(repo.id)

    {:ok, _score} = readiness!(org, repo.id, "wait", 72)
    assert {:error, :readiness_not_ship} = Gates.readiness_gate(repo.id)

    {:ok, _score} = readiness!(org, repo.id, "ship", 91)
    assert :ok = Gates.readiness_gate(repo.id)
  end

  test "branch_protection_gate enforces required approvals and checks" do
    %{pull_request: pull_request, repo: repo, reviewer: reviewer} =
      pr_fixture!("branch-protection")

    {:ok, _branch} =
      Forge.create_branch(%{
        repository_id: repo.id,
        name: "main",
        current_sha: pull_request.base_sha,
        protected: true,
        required_approvals: 2,
        required_checks: ["unit tests", "security"]
      })

    assert {:error, :branch_protection_missing_approvals} =
             Gates.branch_protection_gate(pull_request)

    {:ok, second_reviewer} =
      Actors.create_actor(%{
        organization_id: repo.organization_id,
        type: "human",
        display_name: "Second Reviewer",
        trust_level: "trusted"
      })

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ship it"
      })

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: second_reviewer.id,
        status: "approve",
        summary: "Ship it too"
      })

    assert {:error, :branch_protection_missing_checks} =
             Gates.branch_protection_gate(pull_request)

    {:ok, _check} =
      Forge.upsert_check_run(repo.id, pull_request.id, %{
        provider: "github",
        external_id: "check-unit",
        name: "unit tests",
        status: "completed",
        conclusion: "success"
      })

    assert {:error, :branch_protection_missing_checks} =
             Gates.branch_protection_gate(pull_request)

    {:ok, _check} =
      Forge.upsert_check_run(repo.id, pull_request.id, %{
        provider: "github",
        external_id: "check-security",
        name: "security",
        status: "completed",
        conclusion: "success"
      })

    assert :ok = Gates.branch_protection_gate(pull_request)
  end

  test "branch_protection_gate allows unprotected target branches" do
    %{pull_request: pull_request, repo: repo} = pr_fixture!("unprotected-branch")

    {:ok, _branch} =
      Forge.create_branch(%{
        repository_id: repo.id,
        name: "main",
        current_sha: pull_request.base_sha,
        protected: false,
        required_approvals: 2,
        required_checks: ["unit tests"]
      })

    assert :ok = Gates.branch_protection_gate(pull_request)
  end

  test "base_freshness_gate blocks stale pull request base sha" do
    %{pull_request: pull_request, repo: repo} = pr_fixture!("stale-base")

    assert :ok = Gates.base_freshness_gate(pull_request)

    {:ok, _branch} =
      Forge.create_branch(%{
        repository_id: repo.id,
        name: "main",
        current_sha: "new-main-sha",
        protected: true
      })

    assert {:error, :stale_base_sha} = Gates.base_freshness_gate(pull_request)
  end

  defp pr_fixture!(suffix) do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Merge Gates #{suffix}",
        slug: "merge-gates-#{suffix}"
      })

    {:ok, author} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Author #{suffix}",
        trust_level: "trusted"
      })

    {:ok, reviewer} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Reviewer #{suffix}",
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
        author_actor_id: author.id,
        title: "Change",
        source_branch: "feature/#{suffix}",
        target_branch: "main",
        head_sha: "head-#{suffix}",
        base_sha: "base-#{suffix}",
        status: "ready_for_review"
      })

    %{org: org, pull_request: pull_request, repo: repo, reviewer: reviewer}
  end

  defp readiness!(org, repository_id, verdict, score) do
    Maestro.create_readiness_score(%{
      organization_id: org.id,
      repository_id: repository_id,
      score: score,
      verdict: verdict,
      confidence: "high",
      dimensions: readiness_dimensions(score),
      explanation: "Readiness #{verdict}"
    })
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
