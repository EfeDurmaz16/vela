defmodule Vela.JobsScoreRecalculationTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Forge, Repo}
  alias Vela.Jobs.ScoreRecalculationWorker
  alias Vela.Maestro.ReadinessScore

  test "score recalculation worker creates readiness score and evidence" do
    %{org: org, repo: repo, pr: pr, actor: actor} = fixture!()

    {:ok, _file} =
      Forge.upsert_pull_request_file(pr.id, %{
        path: "apps/web/lib/vela/auth/token.ex",
        previous_path: nil,
        status: "modified",
        blob_sha: nil,
        additions: 18,
        deletions: 4,
        changes: 22,
        patch: nil,
        blob_url: nil,
        raw_url: nil
      })

    {:ok, _test_file} =
      Forge.upsert_pull_request_file(pr.id, %{
        path: "apps/web/test/vela/auth/token_test.exs",
        previous_path: nil,
        status: "added",
        blob_sha: nil,
        additions: 24,
        deletions: 0,
        changes: 24,
        patch: nil,
        blob_url: nil,
        raw_url: nil
      })

    assert :ok =
             ScoreRecalculationWorker.perform(%Oban.Job{
               args: %{
                 "kind" => "score_recalculation",
                 "organization_id" => org.id,
                 "repository_id" => repo.id,
                 "pull_request_id" => pr.id,
                 "actor_id" => actor.id
               }
             })

    [score] = Repo.all(ReadinessScore)
    assert score.repository_id == repo.id
    assert score.input_refs["pull_request_file_ids"] |> Enum.sort() |> length() == 2
    assert score.dimension_explanations["test_evidence"] =~ "Test evidence"

    assert [%{event_type: "score.computed", resource_id: score_id, payload: payload}] =
             Vela.Evidence.list_repository_events(repo.id, 1)

    assert score_id == score.id
    assert payload["score"] == score.score
    assert payload["input_refs"]["pull_request_id"] == pr.id
  end

  defp fixture! do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Score Recalculation",
        slug: "score-recalculation-#{System.unique_integer([:positive])}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Score Worker",
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
        title: "Auth change",
        source_branch: "feature/auth",
        target_branch: "main",
        head_sha: "head",
        base_sha: "base",
        status: "ready_for_review"
      })

    %{org: org, repo: repo, pr: pr, actor: actor}
  end
end
