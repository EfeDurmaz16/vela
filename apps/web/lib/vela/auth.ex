defmodule Vela.Auth do
  @moduledoc """
  WorkOS identity reconciliation into Vela's tenant, user, membership, and actor tables.
  """

  alias Vela.Accounts.{Membership, Organization, User}
  alias Vela.Actors.Actor
  alias Vela.Repo

  import Ecto.Query

  def upsert_workos_identity(%{"user" => user_payload} = payload) do
    Repo.transaction(fn ->
      user = upsert_user!(user_payload)
      organization = upsert_organization!(payload)
      membership = upsert_membership!(organization, user, Map.get(payload, "role", "observer"))
      actor = upsert_human_actor!(organization, user)

      %{user: user, organization: organization, membership: membership, actor: actor}
    end)
  end

  defp upsert_user!(payload) do
    workos_user_id = fetch_string!(payload, "id")

    attrs = %{
      workos_user_id: workos_user_id,
      email: fetch_string!(payload, "email"),
      name: display_name(payload),
      avatar_url: Map.get(payload, "profile_picture_url")
    }

    case Repo.get_by(User, workos_user_id: workos_user_id) do
      nil -> User.changeset(%User{}, attrs) |> Repo.insert!()
      user -> User.changeset(user, attrs) |> Repo.update!()
    end
  end

  defp upsert_organization!(%{"organization_id" => workos_org_id} = payload)
       when is_binary(workos_org_id) do
    attrs = %{
      workos_org_id: workos_org_id,
      name: get_in(payload, ["organization", "name"]) || workos_org_id,
      slug: get_in(payload, ["organization", "slug"]) || slugify(workos_org_id),
      plan: "team"
    }

    case Repo.get_by(Organization, workos_org_id: workos_org_id) do
      nil -> Organization.changeset(%Organization{}, attrs) |> Repo.insert!()
      org -> Organization.changeset(org, attrs) |> Repo.update!()
    end
  end

  defp upsert_organization!(%{"user" => user_payload}) do
    domain =
      user_payload
      |> fetch_string!("email")
      |> String.split("@")
      |> List.last()

    slug = slugify(domain)

    attrs = %{name: domain, slug: slug, plan: "free"}

    case Repo.get_by(Organization, slug: slug) do
      nil -> Organization.changeset(%Organization{}, attrs) |> Repo.insert!()
      org -> org
    end
  end

  defp upsert_membership!(organization, user, role) do
    role = if role in Membership.roles(), do: role, else: "observer"
    attrs = %{organization_id: organization.id, user_id: user.id, role: role}

    case Repo.get_by(Membership, organization_id: organization.id, user_id: user.id) do
      nil -> Membership.changeset(%Membership{}, attrs) |> Repo.insert!()
      membership -> Membership.changeset(membership, attrs) |> Repo.update!()
    end
  end

  defp upsert_human_actor!(organization, user) do
    external_ref = "workos:#{user.workos_user_id}"

    attrs = %{
      organization_id: organization.id,
      created_by_user_id: user.id,
      type: "human",
      display_name: user.name,
      trust_level: "trusted",
      external_ref: external_ref
    }

    query =
      from a in Actor,
        where: a.organization_id == ^organization.id and a.external_ref == ^external_ref

    case Repo.one(query) do
      nil -> Actor.changeset(%Actor{}, attrs) |> Repo.insert!()
      actor -> Actor.changeset(actor, attrs) |> Repo.update!()
    end
  end

  defp display_name(payload) do
    [Map.get(payload, "first_name"), Map.get(payload, "last_name")]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> fetch_string!(payload, "email")
      name -> name
    end
  end

  defp fetch_string!(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) and value != "" -> value
      _ -> raise ArgumentError, "missing #{key}"
    end
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
