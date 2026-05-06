defmodule Vela.AuthApiTokenTest do
  use Vela.DataCase, async: true

  alias Vela.{Accounts, Actors, Auth}
  alias Vela.Auth.ApiToken

  test "creates service token metadata for an organization and actor" do
    %{actor: actor, org: org} = auth_fixture!("create")
    expires_at = DateTime.add(DateTime.utc_now(:second), 3600, :second)

    assert {:ok, %ApiToken{} = token} =
             Auth.create_api_token(%{
               organization_id: org.id,
               actor_id: actor.id,
               name: "CI deploy token",
               scopes: ["repositories:read", "pull_requests:write"],
               expires_at: expires_at
             })

    assert token.organization_id == org.id
    assert token.actor_id == actor.id
    assert token.scopes == ["repositories:read", "pull_requests:write"]
    assert token.status == "active"
    assert token.expires_at == expires_at
    assert token.token_hash == nil
  end

  test "requires organization actor scopes and expiry" do
    changeset = ApiToken.changeset(%ApiToken{}, %{name: "missing", scopes: []})

    assert %{
             actor_id: ["can't be blank"],
             expires_at: ["can't be blank"],
             organization_id: ["can't be blank"],
             scopes: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "rejects invalid status and scopes" do
    %{actor: actor, org: org} = auth_fixture!("invalid")

    changeset =
      ApiToken.changeset(%ApiToken{}, %{
        organization_id: org.id,
        actor_id: actor.id,
        name: "bad token",
        scopes: ["repositories:read", "secrets:write"],
        status: "paused",
        expires_at: DateTime.add(DateTime.utc_now(:second), 3600, :second)
      })

    assert %{
             scopes: ["has an invalid entry"],
             status: ["is invalid"]
           } = errors_on(changeset)
  end

  test "rejects unknown organization references" do
    %{actor: actor} = auth_fixture!("unknown-org")

    assert {:error, changeset} =
             Auth.create_api_token(%{
               organization_id: Ecto.UUID.generate(),
               actor_id: actor.id,
               name: "orphan token",
               scopes: ["repositories:read"],
               expires_at: DateTime.add(DateTime.utc_now(:second), 3600, :second)
             })

    assert %{organization_id: ["does not exist"]} = errors_on(changeset)
  end

  test "rejects unknown actor references" do
    %{org: org} = auth_fixture!("unknown-actor")

    assert {:error, changeset} =
             Auth.create_api_token(%{
               organization_id: org.id,
               actor_id: Ecto.UUID.generate(),
               name: "orphan token",
               scopes: ["repositories:read"],
               expires_at: DateTime.add(DateTime.utc_now(:second), 3600, :second)
             })

    assert %{actor_id: ["does not exist"]} = errors_on(changeset)
  end

  defp auth_fixture!(suffix) do
    {:ok, org} =
      Accounts.create_organization(%{
        name: "Token #{suffix}",
        slug: "token-#{suffix}"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        type: "system",
        display_name: "Token Actor #{suffix}",
        trust_level: "trusted"
      })

    %{actor: actor, org: org}
  end
end
