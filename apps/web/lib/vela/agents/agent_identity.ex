defmodule Vela.Agents.AgentIdentity do
  use Vela.Schema

  @statuses ~w(active suspended revoked pending)

  schema "agent_identities" do
    field :did, :string
    field :public_key, :string
    field :trust_score, :integer, default: 0
    field :status, :string, default: "active"

    belongs_to :actor, Vela.Actors.Actor
    belongs_to :issuer_organization, Vela.Accounts.Organization

    timestamps(type: :utc_datetime)
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:actor_id, :did, :public_key, :trust_score, :issuer_organization_id, :status])
    |> validate_required([:actor_id, :trust_score, :status])
    |> Vela.Validation.validate_score(:trust_score)
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> unique_constraint(:actor_id)
    |> unique_constraint(:did)
  end
end
