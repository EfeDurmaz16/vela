defmodule Vela.Merge do
  @moduledoc """
  Deterministic merge candidate metadata and Phase 0 state transitions.
  """

  alias Vela.Merge.MergeCandidate
  alias Vela.Repo

  def create_merge_candidate(attrs),
    do: %MergeCandidate{} |> MergeCandidate.changeset(attrs) |> Repo.insert()

  def transition(%MergeCandidate{} = candidate, next_status, attrs \\ %{}) do
    if Vela.StateMachine.allowed?(:merge_candidate, candidate.status, next_status) do
      candidate
      |> MergeCandidate.changeset(Map.put(attrs, :status, next_status))
      |> Repo.update()
    else
      {:error, {:invalid_transition, candidate.status, next_status}}
    end
  end

  def allowed_transition?(from, to), do: Vela.StateMachine.allowed?(:merge_candidate, from, to)
  def transitions, do: Vela.StateMachine.transitions(:merge_candidate)
end
