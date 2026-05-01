defmodule Vela.Agents.AgentSession do
  use Vela.Schema

  @statuses ~w(active completed failed cancelled blocked)

  schema "agent_sessions" do
    field :task_intent, :string
    field :prompt_hash, :string
    field :model, :string
    field :toolchain, :map, default: %{}
    field :status, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :agent_actor, Vela.Actors.Actor
    belongs_to :human_supervisor, Vela.Accounts.User
    belongs_to :branch, Vela.Forge.Branch

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :agent_actor_id,
      :human_supervisor_id,
      :branch_id,
      :task_intent,
      :prompt_hash,
      :model,
      :toolchain,
      :status,
      :started_at,
      :ended_at
    ])
    |> validate_required([
      :organization_id,
      :repository_id,
      :agent_actor_id,
      :task_intent,
      :status,
      :started_at
    ])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
  end
end
