defmodule VelaWeb.HealthController do
  use VelaWeb, :controller

  def health(conn, _params), do: json(conn, %{status: "ok"})
  def ready(conn, _params), do: json(conn, %{status: "ready"})

  def metrics(conn, _params) do
    text(conn, """
    # HELP vela_up Whether the Vela API process is serving requests.
    # TYPE vela_up gauge
    vela_up 1
    """)
  end
end
