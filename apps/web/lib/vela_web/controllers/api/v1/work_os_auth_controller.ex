defmodule VelaWeb.Api.V1.WorkOSAuthController do
  use VelaWeb, :controller

  alias Vela.Auth
  alias Vela.Auth.WorkOS
  alias VelaWeb.Plugs.ApiAuth

  def login(conn, params) do
    config = workos_config()

    attrs = %{
      client_id: Keyword.get(config, :client_id),
      redirect_uri: Keyword.get(config, :redirect_uri),
      state: Map.get(params, "state"),
      provider: "authkit"
    }

    with {:ok, url} <- WorkOS.authorization_url(attrs) do
      json(conn, %{data: %{authorization_url: URI.to_string(url)}})
    end
  end

  def callback(conn, %{"code" => code}) do
    config = workos_config()

    attrs = %{
      api_key: Keyword.get(config, :api_key),
      client_id: Keyword.get(config, :client_id),
      code: code,
      ip_address: conn.remote_ip |> :inet.ntoa() |> to_string(),
      user_agent: get_req_header(conn, "user-agent") |> List.first(),
      transport: Keyword.get(config, :transport)
    }

    with {:ok, auth_payload} <- WorkOS.exchange_code(attrs),
         {:ok, %{user: user, organization: org, membership: membership, actor: actor}} <-
           Auth.upsert_workos_identity(auth_payload) do
      conn
      |> configure_session(renew: true)
      |> put_session(ApiAuth.session_key(), %{
        "user_id" => user.id,
        "organization_id" => org.id,
        "membership_id" => membership.id,
        "actor_id" => actor.id
      })
      |> json(%{
        data: %{
          user_id: user.id,
          organization_id: org.id,
          membership_id: membership.id,
          actor_id: actor.id,
          role: membership.role
        }
      })
    end
  end

  def callback(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_code"}})
  end

  defp workos_config, do: Application.get_env(:vela, :workos, [])
end
