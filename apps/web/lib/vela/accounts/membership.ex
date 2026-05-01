defmodule Vela.Accounts.Membership do
  use Vela.Schema

  @roles ~w(owner admin maintainer developer reviewer observer)

  schema "memberships" do
    field :role, :string

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :user, Vela.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:organization_id, :user_id, :role])
    |> validate_required([:organization_id, :user_id, :role])
    |> Vela.Validation.validate_inclusion(:role, @roles)
    |> unique_constraint([:organization_id, :user_id])
  end
end
