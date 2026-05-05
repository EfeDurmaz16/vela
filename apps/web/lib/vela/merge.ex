defmodule Vela.Merge do
  @moduledoc """
  Deterministic merge candidate metadata and Phase 0 state transitions.
  """

  import Ecto.Query

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

  def queue_after_successful_review(%Vela.Forge.PullRequest{} = pull_request) do
    with :ok <- review_gate(pull_request.id),
         :ok <- readiness_gate(pull_request.repository_id),
         %MergeCandidate{} = candidate <- latest_candidate(pull_request.id),
         {:ok, queued} <- transition(candidate, "queued") do
      {:ok, queued}
    else
      nil -> {:error, :missing_merge_candidate}
      {:error, reason} -> {:error, reason}
    end
  end

  def allowed_transition?(from, to), do: Vela.StateMachine.allowed?(:merge_candidate, from, to)
  def transitions, do: Vela.StateMachine.transitions(:merge_candidate)

  defp review_gate(pull_request_id) do
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

  defp readiness_gate(repository_id) do
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

  defp latest_candidate(pull_request_id) do
    MergeCandidate
    |> where([c], c.pull_request_id == ^pull_request_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
