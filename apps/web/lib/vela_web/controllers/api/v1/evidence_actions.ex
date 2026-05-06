defmodule VelaWeb.Api.V1.EvidenceActions do
  @moduledoc """
  Evidence verification actions for the v1 JSON API.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Vela.Evidence

  def verify_chain(conn, %{"organization_id" => organization_id} = params) do
    repository_id = Map.get(params, "repository_id")

    case Evidence.verify_chain(organization_id, repository_id) do
      {:ok, summary} ->
        json(conn, %{
          data: %{
            valid: true,
            organization_id: organization_id,
            repository_id: repository_id,
            count: summary.count,
            last_hash: summary.last_hash
          }
        })

      {:error, error} ->
        json(conn, %{
          data: %{
            valid: false,
            organization_id: organization_id,
            repository_id: repository_id,
            reason: error.reason,
            event_id: error.event_id,
            event_hash: error.event_hash
          }
        })
    end
  end

  def verify_chain(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "validation_failed", details: %{organization_id: ["is required"]}}})
  end
end
