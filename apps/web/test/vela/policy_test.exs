defmodule Vela.PolicyTest do
  use ExUnit.Case, async: true

  alias Vela.Actors.Actor
  alias Vela.Agents.AgentPolicy
  alias Vela.Forge.PullRequest
  alias Vela.Maestro.LaunchReadinessScore
  alias Vela.Merge.MergeCandidate
  alias Vela.Policy

  test "fails closed for missing or blocked actors" do
    assert Policy.evaluate_merge(%{}).verdict == :block

    assert Policy.evaluate_merge(%{actor: %Actor{trust_level: "blocked"}}).verdict == :block
  end

  test "blocks agent path violations and merge attempts without permission" do
    result =
      Policy.evaluate_merge(%{
        actor: %Actor{type: "agent", trust_level: "trusted"},
        agent_policy: %AgentPolicy{
          allowed_paths: ["/apps"],
          forbidden_paths: ["/billing"],
          can_merge: false
        },
        pull_request: %PullRequest{status: "ready_for_review"},
        readiness_score: %LaunchReadinessScore{verdict: "ship"},
        merge_candidate: %MergeCandidate{status: "ready"},
        changed_paths: ["/billing/plan.ex"],
        merge_intent: true,
        human_review_status: "approve"
      })

    assert result.verdict == :block
    assert Enum.any?(result.reasons, &String.contains?(&1, "forbidden_paths"))
    assert Enum.any?(result.reasons, &String.contains?(&1, "cannot merge"))
  end

  test "wait verdict requires human override and approved human can pass" do
    wait =
      Policy.evaluate_merge(%{
        actor: %Actor{type: "human", trust_level: "trusted"},
        pull_request: %PullRequest{status: "ready_for_review"},
        readiness_score: %LaunchReadinessScore{verdict: "wait"},
        merge_candidate: %MergeCandidate{status: "ready"}
      })

    allow =
      Policy.evaluate_merge(%{
        actor: %Actor{type: "human", trust_level: "trusted"},
        pull_request: %PullRequest{status: "ready_for_review"},
        readiness_score: %LaunchReadinessScore{verdict: "ship"},
        merge_candidate: %MergeCandidate{status: "ready"}
      })

    assert wait.verdict == :requires_human_override
    assert allow.verdict == :allow
  end
end
