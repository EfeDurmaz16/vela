defmodule Vela.Forge.Change do
  use Vela.Schema

  @statuses Vela.StateMachine.states(:change)
  @risk_levels ~w(low medium high critical)

  schema "changes" do
    field :title, :string
    field :description, :string
    field :source_ref, :string
    field :target_ref, :string
    field :head_sha, :string
    field :base_sha, :string
    field :status, :string, default: "draft"
    field :risk_level, :string, default: "medium"
    field :metadata, :map, default: %{}

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :author_actor, Vela.Actors.Actor
    has_many :readiness_scores, Vela.Maestro.ReadinessScore

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(change, attrs) do
    change
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :author_actor_id,
      :title,
      :description,
      :source_ref,
      :target_ref,
      :head_sha,
      :base_sha,
      :status,
      :risk_level,
      :metadata
    ])
    |> validate_required([:organization_id, :repository_id, :author_actor_id, :title, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> Vela.Validation.validate_inclusion(:risk_level, @risk_levels)
  end
end
