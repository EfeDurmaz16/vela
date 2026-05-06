defmodule VelaWeb.Api.V1.Response do
  @moduledoc """
  Shared response helpers for the v1 JSON API.
  """

  import Phoenix.Controller
  import Plug.Conn

  def paged(conn, entries, params) do
    page_size = page_size(params)

    json(conn, %{
      data: entries |> Enum.take(page_size) |> Enum.map(&serialize/1),
      pagination: %{limit: page_size, returned: min(length(entries), page_size)}
    })
  end

  def page_size(params) do
    case Integer.parse(to_string(Map.get(params, "limit", "25"))) do
      {limit, ""} when limit > 0 and limit <= 100 -> limit
      _ -> 25
    end
  end

  def serialize(%schema{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.reject(fn {_key, value} -> match?(%Ecto.Association.NotLoaded{}, value) end)
    |> Map.drop([:__meta__, :organization, :repository, :actor, :author_actor])
    |> Map.put(:type, schema |> Module.split() |> List.last() |> Macro.underscore())
  end

  def repo_not_found(conn), do: error(conn, :not_found, "repo_not_found")

  def pull_request_not_found(conn), do: error(conn, :not_found, "pull_request_not_found")

  def merge_candidate_not_found(conn), do: error(conn, :not_found, "merge_candidate_not_found")

  def analysis_run_not_found(conn), do: error(conn, :not_found, "analysis_run_not_found")

  def forbidden(conn), do: error(conn, :forbidden, "forbidden")

  def validation_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "validation_failed", details: errors_on(changeset)}})
  end

  def github_error(conn, reason) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: %{code: "github_comment_failed", reason: inspect(reason)}})
  end

  def merge_gate_error(conn, reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: %{code: "merge_gate_failed", reason: to_string(reason)}})
  end

  defp error(conn, status, code) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code}})
  end

  defp errors_on(changeset) do
    if is_map(changeset) and Map.has_key?(changeset, :errors) do
      changeset.errors
    else
      traverse_errors(changeset)
    end
  end

  defp traverse_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
