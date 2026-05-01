defmodule Vela.Forge.Branch do
  use Vela.Schema

  schema "branches" do
    field :name, :string
    field :current_sha, :string
    field :protected, :boolean, default: false
    field :leased_by_agent_session_id, :binary_id

    belongs_to :repository, Vela.Forge.Repository

    timestamps(type: :utc_datetime)
  end

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [:repository_id, :name, :current_sha, :protected, :leased_by_agent_session_id])
    |> validate_required([:repository_id, :name, :current_sha])
    |> unique_constraint([:repository_id, :name])
  end
end
