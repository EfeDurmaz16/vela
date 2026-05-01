defmodule Vela.Accounts.Organization do
  use Vela.Schema

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :plan, :string, default: "free"
    field :workos_org_id, :string

    has_many :memberships, Vela.Accounts.Membership
    has_many :repositories, Vela.Forge.Repository
    has_many :actors, Vela.Actors.Actor

    timestamps(type: :utc_datetime)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :plan, :workos_org_id])
    |> validate_required([:name, :slug, :plan])
    |> unique_constraint(:slug)
    |> unique_constraint(:workos_org_id)
  end
end
