defmodule Vela.MergeTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Forge, Maestro, Repo}
  alias Vela.Merge
  alias Vela.Merge.MergeCandidate

  test "validates allowed state transitions" do
    assert Merge.allowed_transition?("pending", "simulating")
    assert Merge.allowed_transition?("simulating", "testing")
    assert Merge.allowed_transition?("testing", "ready")
    refute Merge.allowed_transition?("pending", "merged")
  end

  test "blocks ready or merged tree mismatches" do
    changeset =
      MergeCandidate.changeset(%MergeCandidate{}, %{
        repository_id: Ecto.UUID.generate(),
        pull_request_id: Ecto.UUID.generate(),
        base_sha: "base",
        head_sha: "head",
        status: "ready",
        tested_tree_hash: "tree:a",
        final_merge_tree_hash: "tree:b"
      })

    refute changeset.valid?
    assert {"must match tested_tree_hash", _} = changeset.errors[:final_merge_tree_hash]
  end

  test "classifies merge tree equivalence state" do
    assert "unmerged" = Vela.Merge.TreeEquivalence.classify(%{})

    assert "untested" =
             Vela.Merge.TreeEquivalence.classify(%{virtual_merge_tree_hash: "tree:virtual"})

    assert "tested" =
             Vela.Merge.TreeEquivalence.classify(%{
               virtual_merge_tree_hash: "tree:virtual",
               tested_tree_hash: "tree:tested"
             })

    assert "equivalent" =
             Vela.Merge.TreeEquivalence.classify(%{
               virtual_merge_tree_hash: "tree:virtual",
               tested_tree_hash: "tree:tested",
               final_merge_tree_hash: "tree:tested"
             })

    assert "mismatch" =
             Vela.Merge.TreeEquivalence.classify(%{
               virtual_merge_tree_hash: "tree:virtual",
               tested_tree_hash: "tree:tested",
               final_merge_tree_hash: "tree:final"
             })
  end

  test "stores tree_state from merge tree hashes" do
    changeset =
      MergeCandidate.changeset(%MergeCandidate{}, %{
        repository_id: Ecto.UUID.generate(),
        pull_request_id: Ecto.UUID.generate(),
        base_sha: "base",
        head_sha: "head",
        status: "pending",
        virtual_merge_tree_hash: "tree:virtual",
        tested_tree_hash: "tree:tested"
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :tree_state) == "tested"
  end

  test "blocks final tree mismatch when candidate becomes ready" do
    %{candidate: candidate} = merge_fixture!("tree-mismatch")

    assert {:error, changeset} =
             Merge.transition(candidate, "simulating", %{
               virtual_merge_tree_hash: "tree:virtual"
             })
             |> then(fn {:ok, candidate} ->
               Merge.transition(candidate, "testing", %{tested_tree_hash: "tree:tested"})
             end)
             |> then(fn {:ok, candidate} ->
               Merge.transition(candidate, "ready", %{final_merge_tree_hash: "tree:final"})
             end)

    assert {"must match tested_tree_hash", _} = changeset.errors[:final_merge_tree_hash]
  end

  test "queues merge only when review and readiness gates pass" do
    %{pr: pr, candidate: candidate, reviewer: reviewer} = merge_fixture!("passing")

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pr.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ready"
      })

    {:ok, _score} =
      Maestro.create_readiness_score(%{
        organization_id: pr.repository.organization_id,
        repository_id: pr.repository_id,
        score: 88,
        verdict: "ship",
        confidence: "high",
        dimensions: readiness_dimensions(88),
        explanation: "Ready to merge"
      })

    assert {:ok, queued} = Merge.queue_after_successful_review(pr)
    assert queued.id == candidate.id
    assert queued.status == "queued"
  end

  test "rejects merge queue when approval or ship readiness is missing" do
    %{pr: pr, reviewer: reviewer} = merge_fixture!("blocked")

    assert {:error, :missing_approval} = Merge.queue_after_successful_review(pr)

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pr.id,
        actor_id: reviewer.id,
        status: "request_changes",
        summary: "Needs work"
      })

    assert {:error, :blocking_review} = Merge.queue_after_successful_review(pr)
  end

  defp merge_fixture!(suffix) do
    {:ok, org} =
      Accounts.create_organization(%{name: "Merge Gate #{suffix}", slug: "merge-gate-#{suffix}"})

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
        slug: "core",
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
      pr: Repo.preload(pr, :repository),
      candidate: candidate,
      reviewer: reviewer
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
