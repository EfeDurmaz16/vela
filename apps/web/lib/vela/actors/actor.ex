defmodule Vela.Actors.Actor do
  use Vela.Schema

  @types ~w(human agent system integration runner security_scanner deployment_bot)
  @trust_levels ~w(unverified trusted restricted blocked)

  schema "actors" do
    field :type, :string
    field :display_name, :string
    field :trust_level, :string, default: "unverified"
    field :external_ref, :string
    field :signing_key_ref, :string

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :created_by_user, Vela.Accounts.User
    has_one :agent_identity, Vela.Agents.AgentIdentity
    has_many :agent_policies, Vela.Agents.AgentPolicy
    has_many :agent_sessions, Vela.Agents.AgentSession, foreign_key: :agent_actor_id

    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def trust_levels, do: @trust_levels

  def changeset(actor, attrs) do
    actor
    |> cast(attrs, [
      :organization_id,
      :type,
      :display_name,
      :trust_level,
      :external_ref,
      :signing_key_ref,
      :created_by_user_id
    ])
    |> validate_required([:organization_id, :type, :display_name, :trust_level])
    |> Vela.Validation.validate_inclusion(:type, @types)
    |> Vela.Validation.validate_inclusion(:trust_level, @trust_levels)
  end
end
