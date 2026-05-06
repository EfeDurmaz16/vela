defmodule Vela.Evidence.TamperAlarm do
  use Vela.Schema

  @reasons ~w(prev_event_hash_mismatch payload_hash_mismatch event_hash_mismatch)
  @statuses ~w(open acknowledged resolved)

  schema "evidence_tamper_alarms" do
    field :reason, :string
    field :event_hash, :string
    field :status, :string, default: "open"

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :evidence_event, Vela.Evidence.EvidenceEvent

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(alarm, attrs) do
    alarm
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :evidence_event_id,
      :reason,
      :event_hash,
      :status
    ])
    |> validate_required([:organization_id, :reason, :status])
    |> Vela.Validation.validate_inclusion(:reason, @reasons)
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> unique_constraint([:organization_id, :event_hash, :reason])
  end
end
