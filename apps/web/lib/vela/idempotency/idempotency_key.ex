defmodule Vela.Idempotency.IdempotencyKey do
  use Vela.Schema

  schema "idempotency_keys" do
    field :key, :string
    field :request_hash, :string
    field :response_status, :integer
    field :response_body, :map
    field :expires_at, :utc_datetime

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def changeset(idempotency_key, attrs) do
    idempotency_key
    |> cast(attrs, [
      :key,
      :organization_id,
      :actor_id,
      :request_hash,
      :response_status,
      :response_body,
      :expires_at
    ])
    |> validate_required([:key, :organization_id, :request_hash, :expires_at])
    |> unique_constraint([:organization_id, :key])
  end
end
