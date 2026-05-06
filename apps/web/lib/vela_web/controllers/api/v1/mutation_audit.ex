defmodule VelaWeb.Api.V1.MutationAudit do
  @moduledoc """
  Evidence and outbox writes for accepted API mutations.
  """

  alias Vela.Evidence
  alias Vela.Outbox.OutboxEvent
  alias Vela.Repo

  def record_pr_comment!(conn, pull_request, review, github_payload) do
    payload = %{
      review_id: review.id,
      pull_request_id: pull_request.id,
      github: github_payload
    }

    append_event!(conn, %{
      organization_id: conn.assigns.current_organization.id,
      repository_id: pull_request.repository_id,
      event_type: "pr.comment.created",
      resource_type: "pull_request",
      resource_id: pull_request.id,
      payload: payload
    })

    insert_outbox!(%{
      organization_id: conn.assigns.current_organization.id,
      repository_id: pull_request.repository_id,
      event_type: "pr.comment.created",
      payload: payload
    })

    :ok
  end

  def record_merge_queued!(conn, pull_request, candidate) do
    payload = %{
      pull_request_id: pull_request.id,
      merge_candidate_id: candidate.id,
      base_sha: candidate.base_sha,
      head_sha: candidate.head_sha,
      queued_by_actor_id: conn.assigns.current_actor.id
    }

    append_event!(conn, %{
      organization_id: conn.assigns.current_organization.id,
      repository_id: pull_request.repository_id,
      event_type: "merge.queued",
      resource_type: "merge_candidate",
      resource_id: candidate.id,
      payload: payload
    })

    insert_outbox!(%{
      organization_id: conn.assigns.current_organization.id,
      repository_id: pull_request.repository_id,
      event_type: "merge.queued",
      payload: payload
    })

    :ok
  end

  def record_merge_cancelled!(conn, candidate) do
    payload = %{
      merge_candidate_id: candidate.id,
      pull_request_id: candidate.pull_request_id,
      base_sha: candidate.base_sha,
      head_sha: candidate.head_sha,
      cancelled_by_actor_id: conn.assigns.current_actor.id
    }

    append_event!(conn, %{
      organization_id: conn.assigns.current_organization.id,
      repository_id: candidate.repository_id,
      event_type: "merge.cancelled",
      resource_type: "merge_candidate",
      resource_id: candidate.id,
      payload: payload
    })

    insert_outbox!(%{
      organization_id: conn.assigns.current_organization.id,
      repository_id: candidate.repository_id,
      event_type: "merge.cancelled",
      payload: payload
    })

    :ok
  end

  def record_job_accepted!(conn, attrs) do
    payload = %{
      job_id: attrs.job.id,
      job_kind: attrs.job.args["kind"],
      queue: attrs.job.queue,
      actor_id: conn.assigns.current_actor.id
    }

    append_event!(conn, %{
      organization_id: attrs.organization_id,
      repository_id: attrs.repository_id,
      event_type: attrs.event_type,
      resource_type: attrs.resource_type,
      resource_id: attrs.resource_id,
      payload: payload
    })

    insert_outbox!(%{
      organization_id: attrs.organization_id,
      repository_id: attrs.repository_id,
      event_type: attrs.event_type,
      payload: Map.put(payload, :resource_id, attrs.resource_id)
    })
  end

  defp append_event!(conn, attrs) do
    {:ok, _event} =
      attrs
      |> Map.put(:actor_id, conn.assigns.current_actor.id)
      |> Evidence.append_event()
  end

  defp insert_outbox!(attrs) do
    %OutboxEvent{}
    |> OutboxEvent.changeset(Map.put(attrs, :status, "pending"))
    |> Repo.insert!()
  end
end
