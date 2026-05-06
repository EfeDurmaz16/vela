defmodule VelaWeb.Api.V1.PullRequestMergeActionsTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Forge, Maestro, Merge, Repo}
  alias Vela.Outbox.OutboxEvent
  alias VelaWeb.Api.V1.PullRequestActions

  test "queue_merge queues a reviewed pull request with ship readiness" do
    %{candidate: candidate, conn: conn, org: org, pull_request: pull_request, reviewer: reviewer} =
      pr_fixture!("passing")

    approve!(pull_request, reviewer)
    readiness!(org, pull_request.repository_id, "ship")

    response =
      conn
      |> PullRequestActions.queue_merge(pull_request)
      |> json_response(202)

    assert %{
             "data" => %{
               "pull_request_id" => pull_request_id,
               "merge_candidate" => %{"id" => candidate_id, "status" => "queued"}
             }
           } = response

    assert pull_request_id == pull_request.id
    assert candidate_id == candidate.id
    assert Repo.get!(Merge.MergeCandidate, candidate.id).status == "queued"

    assert [%{event_type: "merge.queued", resource_id: ^candidate_id}] =
             Evidence.list_repository_events(pull_request.repository_id, 5)

    assert [%OutboxEvent{event_type: "merge.queued", repository_id: repository_id}] =
             OutboxEvent |> Repo.all()

    assert repository_id == pull_request.repository_id
  end

  test "queue_merge rejects missing approval" do
    %{conn: conn, pull_request: pull_request} = pr_fixture!("missing-approval")

    response =
      conn
      |> PullRequestActions.queue_merge(pull_request)
      |> json_response(422)

    assert response == %{
             "error" => %{"code" => "merge_gate_failed", "reason" => "missing_approval"}
           }
  end

  test "queue_merge rejects blocking reviews" do
    %{conn: conn, pull_request: pull_request, reviewer: reviewer} = pr_fixture!("blocking-review")

    {:ok, _review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: reviewer.id,
        status: "request_changes",
        summary: "Fix this first"
      })

    response =
      conn
      |> PullRequestActions.queue_merge(pull_request)
      |> json_response(422)

    assert response == %{
             "error" => %{"code" => "merge_gate_failed", "reason" => "blocking_review"}
           }
  end

  test "queue_merge rejects non-ship readiness" do
    %{conn: conn, org: org, pull_request: pull_request, reviewer: reviewer} =
      pr_fixture!("wait-readiness")

    approve!(pull_request, reviewer)
    readiness!(org, pull_request.repository_id, "wait")

    response =
      conn
      |> PullRequestActions.queue_merge(pull_request)
      |> json_response(422)

    assert response == %{
             "error" => %{"code" => "merge_gate_failed", "reason" => "readiness_not_ship"}
           }
  end

  defp pr_fixture!(suffix) do
    unique = System.unique_integer([:positive])

    {:ok, org} =
      Accounts.create_organization(%{
        name: "PR Merge Action #{suffix}",
        slug: "pr-merge-action-#{suffix}-#{unique}"
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
        slug: "core-#{unique}",
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
        source_branch: "feature",
        target_branch: "main",
        head_sha: "head",
        base_sha: "base",
        status: "ready_for_review"
      })

    {:ok, candidate} =
      Merge.create_merge_candidate(%{
        repository_id: repo.id,
        pull_request_id: pull_request.id,
        base_sha: "base",
        head_sha: "head",
        status: "pending"
      })

    pull_request = %{pull_request | repository: repo}

    conn =
      Plug.Test.conn(:post, "/api/v1/pull-requests/#{pull_request.id}/merge")
      |> Plug.Conn.assign(:current_organization, org)
      |> Plug.Conn.assign(:current_actor, reviewer)

    %{
      candidate: candidate,
      conn: conn,
      org: org,
      pull_request: pull_request,
      reviewer: reviewer
    }
  end

  defp approve!(pull_request, reviewer) do
    Forge.create_review(%{
      pull_request_id: pull_request.id,
      actor_id: reviewer.id,
      status: "approve",
      summary: "Ship it"
    })
  end

  defp readiness!(org, repository_id, verdict) do
    Maestro.create_readiness_score(%{
      organization_id: org.id,
      repository_id: repository_id,
      score: if(verdict == "ship", do: 91, else: 72),
      verdict: verdict,
      confidence: "high",
      dimensions: readiness_dimensions(if(verdict == "ship", do: 91, else: 72)),
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
