defmodule VelaWeb.WorkOSAuthControllerTest do
  use VelaWeb.ConnCase, async: false

  test "login endpoint returns a server-generated WorkOS authorization URL", %{conn: conn} do
    previous = Application.get_env(:vela, :workos)

    Application.put_env(:vela, :workos,
      client_id: "client_123",
      redirect_uri: "https://vela.test/api/v1/auth/workos/callback"
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :workos, previous),
        else: Application.delete_env(:vela, :workos)
    end)

    response =
      conn
      |> get(~p"/api/v1/auth/workos/login")
      |> json_response(200)

    assert %{"data" => %{"authorization_url" => url}} = response
    assert String.contains?(url, "api.workos.com/user_management/authorize")
    assert String.contains?(url, "client_123")
  end

  test "callback exchanges WorkOS code and reconciles the identity", %{conn: conn} do
    previous = Application.get_env(:vela, :workos)

    Application.put_env(:vela, :workos,
      api_key: "sk_test",
      client_id: "client_123",
      transport: fn _req ->
        {:ok,
         %{
           status: 200,
           body: %{
             "user" => %{
               "id" => "user_123",
               "email" => "efe@example.com",
               "first_name" => "Efe"
             },
             "organization_id" => "org_123",
             "role" => "owner"
           }
         }}
      end
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :workos, previous),
        else: Application.delete_env(:vela, :workos)
    end)

    response =
      conn
      |> get(~p"/api/v1/auth/workos/callback?code=code_123")
      |> json_response(200)

    assert %{
             "data" => %{
               "user_id" => user_id,
               "organization_id" => organization_id,
               "role" => "owner"
             }
           } = response

    assert Vela.Repo.get!(Vela.Accounts.User, user_id).workos_user_id == "user_123"
    assert Vela.Repo.get!(Vela.Accounts.Organization, organization_id).workos_org_id == "org_123"
  end

  test "callback persists the authenticated identity in the Phoenix session", %{conn: conn} do
    previous = Application.get_env(:vela, :workos)

    Application.put_env(:vela, :workos,
      api_key: "sk_test",
      client_id: "client_123",
      transport: fn _req ->
        {:ok,
         %{
           status: 200,
           body: %{
             "user" => %{
               "id" => "user_session",
               "email" => "session@example.com",
               "first_name" => "Session"
             },
             "organization_id" => "org_session",
             "role" => "admin"
           }
         }}
      end
    )

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :workos, previous),
        else: Application.delete_env(:vela, :workos)
    end)

    conn =
      conn
      |> get(~p"/api/v1/auth/workos/callback?code=code_session")
      |> fetch_session()

    assert %{
             "user_id" => user_id,
             "organization_id" => organization_id,
             "membership_id" => membership_id,
             "actor_id" => actor_id
           } = get_session(conn, "vela_api_auth")

    assert json_response(conn, 200)["data"]["user_id"] == user_id
    assert Vela.Repo.get!(Vela.Accounts.User, user_id).workos_user_id == "user_session"

    assert Vela.Repo.get!(Vela.Accounts.Organization, organization_id).workos_org_id ==
             "org_session"

    assert Vela.Repo.get!(Vela.Accounts.Membership, membership_id).role == "admin"
    assert Vela.Repo.get!(Vela.Actors.Actor, actor_id).type == "human"
  end
end
