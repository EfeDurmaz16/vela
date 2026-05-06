defmodule VelaWeb.AnalysisCallbackTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Forge, Maestro, Repo, Webhooks}
  alias Vela.Maestro.AnalysisRun

  setup do
    previous = Application.get_env(:vela, :webhooks)

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      tolerance_seconds: 300,
      now: fn -> 1_777_990_000 end,
      secrets: %{"analysis" => "analysis_secret"}
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :webhooks, previous),
        else: Application.delete_env(:vela, :webhooks)
    end)
  end

  test "signed analysis callback completes an analysis run", %{conn: conn} do
    %{analysis_run: analysis_run} = analysis_fixture!()

    body =
      Jason.encode!(%{
        status: "completed",
        summary: "External analyzer finished with deterministic inputs.",
        completed_at: "2026-05-06T13:10:00Z"
      })

    timestamp = "1777990000"
    signature = Webhooks.sign("analysis_secret", timestamp, body)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("x-vela-timestamp", timestamp)
      |> put_req_header("x-vela-signature", signature)
      |> post(~p"/api/v1/analysis-runs/#{analysis_run.id}/callback", body)
      |> json_response(202)

    assert %{
             "data" => %{
               "id" => analysis_run_id,
               "status" => "completed",
               "summary" => "External analyzer finished with deterministic inputs."
             }
           } = response

    assert analysis_run_id == analysis_run.id

    assert %AnalysisRun{status: "completed", summary: summary, completed_at: completed_at} =
             Repo.get!(AnalysisRun, analysis_run.id)

    assert summary == "External analyzer finished with deterministic inputs."
    assert completed_at == ~U[2026-05-06 13:10:00Z]
  end

  test "analysis callback rejects unsigned payloads when signatures are required", %{conn: conn} do
    %{analysis_run: analysis_run} = analysis_fixture!()

    response =
      conn
      |> post(~p"/api/v1/analysis-runs/#{analysis_run.id}/callback", %{
        status: "completed",
        summary: "Unsigned result"
      })
      |> json_response(401)

    assert %{"error" => %{"code" => "analysis_callback_verification_failed"}} = response
    assert %AnalysisRun{status: "queued", summary: nil} = Repo.get!(AnalysisRun, analysis_run.id)
  end

  defp analysis_fixture! do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Analysis Callback",
        slug: "analysis-callback-#{System.unique_integer([:positive])}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "human",
        display_name: "Author",
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

    {:ok, analysis_run} =
      Maestro.create_analysis_run(%{
        organization_id: org.id,
        repository_id: repo.id,
        pull_request_id: pr.id,
        commit_sha: pr.head_sha,
        status: "queued"
      })

    %{analysis_run: analysis_run}
  end
end
