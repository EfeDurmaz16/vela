defmodule VelaWeb.Api.V1.IdempotentMutation do
  @moduledoc """
  Response wrapper for idempotent API mutations.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Vela.Idempotency

  def respond(conn, organization_id, fun) do
    actor_id = conn.assigns.current_actor.id

    case Idempotency.run(conn, organization_id, actor_id, fun) do
      {:ok, {status, body}} ->
        conn |> put_status(status) |> json(body)

      {:replay, {status, body}} ->
        conn |> put_status(status) |> json(body)

      {:conflict, reason} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: to_string(reason)}})
    end
  end
end
