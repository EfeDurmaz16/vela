defmodule Vela.Agents.AgentPolicy do
  use Vela.Schema

  @statuses ~w(active paused revoked)

  schema "agent_policies" do
    field :name, :string
    field :allowed_repos, {:array, :string}, default: []
    field :allowed_branches, {:array, :string}, default: []
    field :allowed_paths, {:array, :string}, default: []
    field :forbidden_paths, {:array, :string}, default: []
    field :max_pr_size, :integer
    field :requires_human_approval, :boolean, default: true
    field :can_create_pr, :boolean, default: false
    field :can_merge, :boolean, default: false
    field :can_deploy, :boolean, default: false
    field :status, :string, default: "active"

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :actor, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [
      :organization_id,
      :actor_id,
      :name,
      :allowed_repos,
      :allowed_branches,
      :allowed_paths,
      :forbidden_paths,
      :max_pr_size,
      :requires_human_approval,
      :can_create_pr,
      :can_merge,
      :can_deploy,
      :status
    ])
    |> validate_required([:organization_id, :actor_id, :name, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_number(:max_pr_size, greater_than: 0)
  end
end
