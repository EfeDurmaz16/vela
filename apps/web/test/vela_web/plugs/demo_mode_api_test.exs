defmodule VelaWeb.Plugs.DemoModeApiTest do
  use VelaWeb.ConnCase, async: false

  alias Vela.{Accounts, Actors, Forge}
  alias VelaWeb.Plugs.ApiAuth

  setup do
    previous = Application.get_env(:vela, :api)

    on_exit(fn ->
      Application.put_env(:vela, :api, previous)
    end)

    :ok
  end

  test "public read API routes reject requests when demo mode is disabled", %{conn: conn} do
    Application.put_env(:vela, :api, demo_mode?: false)

    response =
      conn
      |> get(~p"/api/v1/repos")
      |> json_response(401)

    assert response == %{"error" => %{"code" => "demo_mode_required"}}
  end

  test "authenticated read API routes still work when demo mode is disabled", %{conn: conn} do
    Application.put_env(:vela, :api, demo_mode?: false)

    {:ok, org} =
      Accounts.create_organization(%{name: "Protected Read Org", slug: "protected-read"})

    session = auth_session_for_org!(org)

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
      |> init_test_session(%{ApiAuth.session_key() => session})
      |> get(~p"/api/v1/repos/#{repo.id}")
      |> json_response(200)

    assert %{"data" => %{"id" => repo_id, "organization_id" => org_id}} = response
    assert repo_id == repo.id
    assert org_id == org.id
  end

  defp auth_session_for_org!(org) do
    {:ok, user} =
      Accounts.create_user(%{
        email: "protected-read@example.com",
        name: "Protected Read",
        workos_user_id: "workos_protected_read"
      })

    {:ok, membership} =
      Accounts.create_membership(%{user_id: user.id, organization_id: org.id, role: "admin"})

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
      "user_id" => user.id,
      "organization_id" => org.id,
      "membership_id" => membership.id,
      "actor_id" => actor.id
    }
  end
end
