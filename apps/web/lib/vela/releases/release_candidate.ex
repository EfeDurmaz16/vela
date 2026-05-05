defmodule Vela.Releases.ReleaseCandidate do
  use Vela.Schema

  @statuses Vela.StateMachine.states(:release_candidate)

  schema "release_candidates" do
    field :version, :string
    field :environment, :string
    field :status, :string, default: "draft"
    field :artifact_ref, :string
    field :rollback_plan, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :merge_candidate, Vela.Merge.MergeCandidate
    belongs_to :created_by_actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :merge_candidate_id,
      :created_by_actor_id,
      :version,
      :environment,
      :status,
      :artifact_ref,
      :rollback_plan,
      :metadata
    ])
    |> validate_required([:organization_id, :repository_id, :version, :environment, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> unique_constraint([:repository_id, :version, :environment])
  end
end
