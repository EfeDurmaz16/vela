defmodule VelaWeb.Plugs.ApiAuthTest do
  use VelaWeb.ConnCase, async: true

  alias Vela.{Accounts, Actors, Forge, Repo}

  @session_key "vela_api_auth"

  test "protected API routes reject missing session", %{conn: conn} do
    response =
      conn
      |> post(~p"/api/v1/repos/00000000-0000-0000-0000-000000000000/import", %{})
      |> json_response(401)

    assert response == %{"error" => %{"code" => "api_auth_required"}}
  end

  test "protected API routes accept a valid WorkOS-backed session", %{conn: conn} do
    %{organization: org, session: session} = identity_fixture("valid")

    {:ok, repo} =
      Forge.create_repository(%{
        organization_id: org.id,
        name: "core",
        slug: "core",
        visibility: "private",
        default_branch: "main",
        health_status: "healthy",
        risk_level: "low"
      })

    response =
      conn
      |> init_test_session(%{@session_key => session})
      |> post(~p"/api/v1/repos/#{repo.id}/import", %{owner: "vela", repo: "core"})
      |> json_response(202)

    assert %{"data" => %{"job" => %{"kind" => "repo_import", "status" => "queued"}}} = response
  end

  test "protected API routes reject stale session references", %{conn: conn} do
    %{session: session} = identity_fixture("stale")
    Repo.delete_all(Vela.Accounts.Membership)

    response =
      conn
      |> init_test_session(%{@session_key => session})
      |> post(~p"/api/v1/repos/00000000-0000-0000-0000-000000000000/import", %{})
      |> json_response(401)

    assert response == %{"error" => %{"code" => "api_auth_required"}}
  end

  defp identity_fixture(suffix) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "user-#{suffix}@example.com",
        name: "User #{suffix}",
        workos_user_id: "workos_user_#{suffix}"
      })

    {:ok, org} =
      Accounts.create_organization(%{
        name: "Org #{suffix}",
        slug: "org-#{suffix}",
        workos_org_id: "workos_org_#{suffix}"
      })

    {:ok, membership} =
      Accounts.create_membership(%{
        user_id: user.id,
        organization_id: org.id,
        role: "admin"
      })

    {:ok, actor} =
      Actors.create_actor(%{
        organization_id: org.id,
        created_by_user_id: user.id,
        type: "human",
        display_name: user.name,
        trust_level: "trusted",
        external_ref: "workos:#{user.workos_user_id}"
      })

    %{
      user: user,
      organization: org,
      membership: membership,
      actor: actor,
      session: %{
        "user_id" => user.id,
        "organization_id" => org.id,
        "membership_id" => membership.id,
        "actor_id" => actor.id
      }
    }
  end
end
