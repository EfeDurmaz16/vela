defmodule Vela.Outbox.OutboxEvent do
  use Vela.Schema

  @statuses ~w(pending publishing published failed)

  schema "outbox_events" do
    field :event_type, :string
    field :payload, :map, default: %{}
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :locked_at, :utc_datetime
    field :published_at, :utc_datetime

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :event_type,
      :payload,
      :status,
      :attempts,
      :locked_at,
      :published_at
    ])
    |> validate_required([:organization_id, :event_type, :payload, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
  end
end
