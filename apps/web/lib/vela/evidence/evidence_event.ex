defmodule Vela.Evidence.EvidenceEvent do
  use Vela.Schema

  @event_types ~w(
    repo.created repo.import_queued repo.imported push.received branch.updated pr.opened pr.updated
    review.submitted agent.session.started agent.session.completed analysis.started
    analysis.completed score.computed policy.evaluated merge.simulated merge.queued
    merge.completed merge.blocked deployment.approved deployment.blocked
    integration.event_received
  )

  schema "evidence_events" do
    field :event_type, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :payload, :map, default: %{}
    field :payload_hash, :string
    field :prev_event_hash, :string
    field :event_hash, :string
    field :signature, :string

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def event_types, do: @event_types

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :actor_id,
      :event_type,
      :resource_type,
      :resource_id,
      :payload,
      :payload_hash,
      :prev_event_hash,
      :event_hash,
      :signature,
      :inserted_at
    ])
    |> validate_required([
      :organization_id,
      :actor_id,
      :event_type,
      :resource_type,
      :payload_hash,
      :event_hash
    ])
    |> Vela.Validation.validate_inclusion(:event_type, @event_types)
    |> unique_constraint(:event_hash)
  end
end
