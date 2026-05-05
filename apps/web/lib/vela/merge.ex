defmodule Vela.Merge do
  @moduledoc """
  Deterministic merge candidate metadata and Phase 0 state transitions.
  """

  alias Vela.Merge.MergeCandidate
  alias Vela.Repo

  def create_merge_candidate(attrs),
    do: %MergeCandidate{} |> MergeCandidate.changeset(attrs) |> Repo.insert()

  def upsert_merge_candidate_by_pull_request(pull_request_id, attrs) do
    case Repo.get_by(MergeCandidate, pull_request_id: pull_request_id) do
      nil -> create_merge_candidate(Map.put(attrs, :pull_request_id, pull_request_id))
      candidate -> candidate |> MergeCandidate.changeset(attrs) |> Repo.update()
    end
  end

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
