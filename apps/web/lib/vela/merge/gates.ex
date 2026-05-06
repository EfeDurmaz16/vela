defmodule Vela.Merge.Gates do
  @moduledoc """
  Merge queue gates that must pass before a candidate can be queued.
  """

  import Ecto.Query

  alias Vela.Repo

  def review_gate(pull_request_id) do
    reviews =
      Vela.Forge.Review
      |> where([r], r.pull_request_id == ^pull_request_id)
      |> Repo.all()

    cond do
      Enum.any?(reviews, &(&1.status in ["request_changes", "block"])) ->
        {:error, :blocking_review}

      Enum.any?(reviews, &(&1.status == "approve")) ->
        :ok

      true ->
        {:error, :missing_approval}
    end
  end

  def readiness_gate(repository_id) do
    latest =
      Vela.Maestro.ReadinessScore
      |> where([s], s.repository_id == ^repository_id)
      |> order_by([s], desc: s.inserted_at)
      |> limit(1)
      |> Repo.one()

    case latest do
      %{verdict: "ship"} -> :ok
      nil -> {:error, :missing_readiness}
      _score -> {:error, :readiness_not_ship}
    end
  end
end
