defmodule Vela.Accounts do
  @moduledoc """
  Organizations, users, memberships, and WorkOS-aligned identity fields.
  """

  alias Vela.Accounts.{Membership, Organization, User}
  alias Vela.Repo

  def create_organization(attrs),
    do: %Organization{} |> Organization.changeset(attrs) |> Repo.insert()

  def create_user(attrs), do: %User{} |> User.changeset(attrs) |> Repo.insert()
  def create_membership(attrs), do: %Membership{} |> Membership.changeset(attrs) |> Repo.insert()

  def get_organization_by_slug!(slug), do: Repo.get_by!(Organization, slug: slug)
  def list_organizations, do: Repo.all(Organization)
end
