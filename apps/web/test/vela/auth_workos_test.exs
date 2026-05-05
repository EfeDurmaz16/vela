defmodule Vela.AuthWorkOSTest do
  use Vela.DataCase, async: true

  alias Vela.Auth
  alias Vela.Repo

  test "upserts WorkOS authenticated user, organization, membership, and human actor" do
    payload = %{
      "user" => %{
        "id" => "user_123",
        "email" => "efe@example.com",
        "first_name" => "Efe",
        "last_name" => "Durmaz",
        "profile_picture_url" => "https://example.com/avatar.png"
      },
      "organization_id" => "org_123",
      "role" => "admin"
    }

    assert {:ok, %{user: user, organization: org, membership: membership, actor: actor}} =
             Auth.upsert_workos_identity(payload)

    assert user.workos_user_id == "user_123"
    assert org.workos_org_id == "org_123"
    assert membership.role == "admin"
    assert actor.external_ref == "workos:user_123"

    assert {:ok, %{user: same_user, organization: same_org}} =
             Auth.upsert_workos_identity(payload)

    assert same_user.id == user.id
    assert same_org.id == org.id
    assert Repo.aggregate(Vela.Accounts.User, :count) == 1
    assert Repo.aggregate(Vela.Accounts.Organization, :count) == 1
  end
end
