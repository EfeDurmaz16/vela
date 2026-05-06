defmodule Vela.Forge.Branch do
  use Vela.Schema

  schema "branches" do
    field :name, :string
    field :current_sha, :string
    field :protected, :boolean, default: false
    field :required_approvals, :integer, default: 1
    field :required_checks, {:array, :string}, default: []
    field :leased_by_agent_session_id, :binary_id

    belongs_to :repository, Vela.Forge.Repository

    timestamps(type: :utc_datetime)
  end

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :repository_id,
      :name,
      :current_sha,
      :protected,
      :required_approvals,
      :required_checks,
      :leased_by_agent_session_id
    ])
    |> validate_required([:repository_id, :name, :current_sha])
    |> validate_number(:required_approvals, greater_than_or_equal_to: 0)
    |> unique_constraint([:repository_id, :name])
  end
end
