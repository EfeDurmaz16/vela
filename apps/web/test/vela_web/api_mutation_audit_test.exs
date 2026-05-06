defmodule VelaWeb.Api.V1.MutationAuditTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Evidence, Forge, Jobs, Merge, Repo}
  alias Vela.Outbox.OutboxEvent
  alias VelaWeb.Api.V1.MutationAudit

  test "record_pr_comment! writes matching evidence and outbox records" do
    %{conn: conn, pull_request: pull_request, review: review, repo: repo} = pr_fixture!("comment")

    assert :ok =
             MutationAudit.record_pr_comment!(conn, pull_request, review, %{
               "id" => 42,
               "html_url" => "https://github.test/comment/42"
             })

    assert [%{event_type: "pr.comment.created", resource_id: resource_id, payload: payload}] =
             Evidence.list_repository_events(repo.id, 5)

    assert resource_id == pull_request.id
    assert payload["review_id"] == review.id
    assert payload["github"]["id"] == 42

    assert [%OutboxEvent{event_type: "pr.comment.created", payload: outbox_payload}] =
             OutboxEvent |> Repo.all()

    assert outbox_payload["review_id"] == review.id
  end

  test "record_merge_queued! writes matching evidence and outbox records" do
    %{candidate: candidate, conn: conn, pull_request: pull_request, repo: repo} =
      pr_fixture!("merge")

    assert :ok = MutationAudit.record_merge_queued!(conn, pull_request, candidate)

    assert [%{event_type: "merge.queued", resource_id: resource_id, payload: payload}] =
             Evidence.list_repository_events(repo.id, 5)

    assert resource_id == candidate.id
    assert payload["merge_candidate_id"] == candidate.id
    assert payload["queued_by_actor_id"] == conn.assigns.current_actor.id

    assert [%OutboxEvent{event_type: "merge.queued", payload: outbox_payload}] =
             OutboxEvent |> Repo.all()

    assert outbox_payload["merge_candidate_id"] == candidate.id
  end

  test "record_job_accepted! writes job evidence and pending outbox" do
    %{actor: actor, conn: conn, organization: organization, repo: repo} = base_fixture!("job")

    {:ok, job} =
      Jobs.enqueue(:repo_import, %{
        organization_id: organization.id,
        repository_id: repo.id,
        actor_id: actor.id,
        provider: "github",
        owner: "vela",
        repo: "vela"
      })

    MutationAudit.record_job_accepted!(conn, %{
      organization_id: organization.id,
      repository_id: repo.id,
      event_type: "repo.import_queued",
      resource_type: "repository",
      resource_id: repo.id,
      job: job
    })

    assert [%{event_type: "repo.import_queued", resource_id: resource_id, payload: payload}] =
             Evidence.list_repository_events(repo.id, 5)

    assert resource_id == repo.id
    assert payload["job_id"] == job.id
    assert payload["actor_id"] == actor.id

    assert [
             %OutboxEvent{
               event_type: "repo.import_queued",
               payload: outbox_payload,
               status: "pending"
             }
           ] = OutboxEvent |> Repo.all()

    assert outbox_payload["resource_id"] == repo.id
  end

  defp pr_fixture!(suffix) do
    %{actor: actor, repo: repo} = fixture = base_fixture!(suffix)

    {:ok, pull_request} =
      Forge.create_pull_request(%{
        repository_id: repo.id,
        author_actor_id: actor.id,
        title: "Trust boundary",
        source_branch: "feature/#{suffix}",
        target_branch: "main",
        head_sha: "head-#{suffix}",
        base_sha: "base-#{suffix}",
        status: "ready_for_review"
      })

    {:ok, review} =
      Forge.create_review(%{
        pull_request_id: pull_request.id,
        actor_id: actor.id,
        status: "comment",
        summary: "Looks bounded."
      })

    {:ok, candidate} =
      Merge.create_merge_candidate(%{
        repository_id: repo.id,
        pull_request_id: pull_request.id,
        base_sha: pull_request.base_sha,
        head_sha: pull_request.head_sha,
        status: "pending"
      })

    Map.merge(fixture, %{candidate: candidate, pull_request: pull_request, review: review})
  end

  defp base_fixture!(suffix) do
    {:ok, organization} =
      Accounts.create_organization(%{
        name: "Mutation Audit #{suffix}",
        slug: "mutation-audit-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: organization.id,
        type: "human",
        display_name: "Audit Actor #{suffix}",
        trust_level: "trusted"
      })

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: organization.id,
        name: "Audit Repo #{suffix}",
        slug: "audit-repo-#{suffix}",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    conn =
      Plug.Test.conn(:post, "/api/v1/audit")
      |> Plug.Conn.assign(:current_organization, organization)
      |> Plug.Conn.assign(:current_actor, actor)

    %{actor: actor, conn: conn, organization: organization, repo: repo}
  end
end
