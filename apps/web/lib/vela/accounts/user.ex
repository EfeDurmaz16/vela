defmodule Vela.Accounts.User do
  use Vela.Schema

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar_url, :string
    field :workos_user_id, :string

    has_many :memberships, Vela.Accounts.Membership
    has_many :created_actors, Vela.Actors.Actor, foreign_key: :created_by_user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :workos_user_id])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint(:email)
    |> unique_constraint(:workos_user_id)
  end
end
