defmodule VelaWeb.Plugs.DemoModeApi do
  @moduledoc """
  Allows unauthenticated read API access only when the explicit demo mode is enabled.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @error %{error: %{code: "demo_mode_required"}}

  def init(opts), do: opts

  def call(conn, _opts) do
    if demo_mode?() do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(@error)
      |> halt()
    end
  end

  def demo_mode? do
    :vela
    |> Application.get_env(:api, [])
    |> Keyword.get(:demo_mode?, false)
  end
end
