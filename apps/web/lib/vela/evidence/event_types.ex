defmodule Vela.Evidence.EventTypes do
  @moduledoc """
  Registry of evidence event types accepted by the control plane.
  """

  @event_types ~w(
    repo.created repo.import_queued repo.imported push.received branch.updated pr.opened pr.updated pr.synced
    pr.comment.created review.submitted agent.session.started agent.session.completed analysis.started
    analysis.completed score.computed policy.evaluated merge.simulated merge.queued
    merge.completed merge.blocked deployment.approved deployment.blocked
    integration.event_received
  )

  def all, do: @event_types
  def known?(event_type), do: event_type in @event_types
end
