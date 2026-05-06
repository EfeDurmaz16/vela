defmodule VelaWeb.Api.V1.AnalysisActions do
  @moduledoc """
  External analysis callback actions for the v1 JSON API.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Vela.{Maestro, Repo, Webhooks}
  alias Vela.Maestro.AnalysisRun
  alias VelaWeb.Api.V1.Response

  @provider "analysis"
  @terminal_statuses ~w(completed failed cancelled)

  def callback(conn, %{"id" => id} = params) do
    case Repo.get(AnalysisRun, id) do
      nil -> Response.analysis_run_not_found(conn)
      analysis_run -> apply_callback(conn, analysis_run, params)
    end
  end

  defp apply_callback(conn, analysis_run, params) do
    with :ok <- Webhooks.verify_provider_request(@provider, conn),
         {:ok, attrs} <- callback_attrs(params),
         {:ok, analysis_run} <- Maestro.update_analysis_run(analysis_run, attrs) do
      conn
      |> put_status(:accepted)
      |> json(%{data: Response.serialize(analysis_run)})
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Response.validation_error(conn, changeset)

      {:error, reason} when reason in [:invalid_status, :invalid_callback] ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "analysis_callback_invalid", reason: to_string(reason)}})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{code: "analysis_callback_verification_failed", reason: to_string(reason)}
        })
    end
  end

  defp callback_attrs(params) do
    status = Map.get(params, "status")

    cond do
      status not in @terminal_statuses ->
        {:error, :invalid_status}

      true ->
        {:ok,
         %{
           status: status,
           summary: Map.get(params, "summary"),
           completed_at: completed_at(params)
         }}
    end
  end

  defp completed_at(%{"completed_at" => completed_at}) when is_binary(completed_at) do
    case DateTime.from_iso8601(completed_at) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      _error -> DateTime.utc_now(:second)
    end
  end

  defp completed_at(_params), do: DateTime.utc_now(:second)
end
