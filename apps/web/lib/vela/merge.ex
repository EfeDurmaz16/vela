defmodule Vela.Merge do
  @moduledoc """
  Deterministic merge candidate metadata and Phase 0 state transitions.
  """

  alias Vela.Merge.MergeCandidate
  alias Vela.Repo

  @transitions %{
    "pending" => ~w(simulating),
    "simulating" => ~w(testing failed blocked),
    "testing" => ~w(ready failed blocked),
    "ready" => ~w(merging cancelled),
    "merging" => ~w(merged failed),
    "blocked" => ~w(simulating cancelled),
    "failed" => ~w(simulating cancelled),
    "cancelled" => [],
    "merged" => []
  }

  def create_merge_candidate(attrs),
    do: %MergeCandidate{} |> MergeCandidate.changeset(attrs) |> Repo.insert()

  def transition(%MergeCandidate{} = candidate, next_status, attrs \\ %{}) do
    allowed = Map.get(@transitions, candidate.status, [])

    if next_status in allowed do
      candidate
      |> MergeCandidate.changeset(Map.put(attrs, :status, next_status))
      |> Repo.update()
    else
      {:error, {:invalid_transition, candidate.status, next_status}}
    end
  end

  def allowed_transition?(from, to), do: to in Map.get(@transitions, from, [])
  def transitions, do: @transitions
end
