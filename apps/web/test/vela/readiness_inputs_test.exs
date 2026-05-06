defmodule Vela.ReadinessInputsTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Forge, Maestro, Repo}
  alias Vela.Maestro.{ReadinessInputs, ReadinessScore}

  test "collects and persists readiness input lineage for a pull request" do
    %{org: org, repo: repo, pr: pr, reviewer: reviewer} = pull_request_fixture!()

    {:ok, file} =
      Forge.upsert_pull_request_file(pr.id, %{
        path: "lib/vela/merge.ex",
        previous_path: nil,
        status: "modified",
        blob_sha: nil,
        additions: 12,
        deletions: 3,
        changes: 15,
        patch: nil,
        blob_url: nil,
        raw_url: nil
      })

    {:ok, review} =
      Forge.create_review(%{
        pull_request_id: pr.id,
        actor_id: reviewer.id,
        status: "approve",
        summary: "Ready"
      })

    {:ok, check_run} =
      Forge.upsert_check_run(repo.id, pr.id, %{
        provider: "github",
        external_id: "check-1",
        name: "test",
        status: "completed",
        conclusion: "success"
      })

    input_refs = ReadinessInputs.collect_for_pull_request(pr.id)

    assert input_refs == %{
             "pull_request_id" => pr.id,
             "pull_request_file_ids" => [file.id],
             "review_ids" => [review.id],
             "check_run_ids" => [check_run.id]
           }

    {:ok, score} =
      Maestro.create_readiness_score(%{
        organization_id: org.id,
        repository_id: repo.id,
        score: 88,
        verdict: "ship",
        confidence: "high",
        dimensions: readiness_dimensions(88),
        explanation: "Reconstructable from PR files, reviews and checks.",
        input_refs: input_refs
      })

    assert Repo.get!(ReadinessScore, score.id).input_refs == input_refs
  end

  defp pull_request_fixture! do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Readiness Inputs",
        slug: "readiness-inputs-#{System.unique_integer([:positive])}"
      })

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

    %{org: org, repo: repo, pr: pr, reviewer: reviewer}
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
