defmodule Vela.Merge do
  @moduledoc """
  Deterministic merge candidate metadata and Phase 0 state transitions.
  """

  import Ecto.Query

  alias Vela.Merge.Gates
  alias Vela.Merge.MergeCandidate
  alias Vela.Repo

  @queue_statuses ~w(queued merging)

  def create_merge_candidate(attrs),
    do: %MergeCandidate{} |> MergeCandidate.changeset(attrs) |> Repo.insert()

  def upsert_merge_candidate_by_pull_request(pull_request_id, attrs) do
    attrs = attrs_with_target_branch(pull_request_id, attrs)

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
    with :ok <- Gates.review_gate(pull_request.id),
         :ok <- Gates.branch_protection_gate(pull_request),
         :ok <- Gates.base_freshness_gate(pull_request),
         :ok <- Gates.readiness_gate(pull_request.repository_id),
         %MergeCandidate{} = candidate <- latest_candidate(pull_request.id),
         {:ok, queued} <- transition(candidate, "queued", queue_attrs(candidate, pull_request)) do
      {:ok, queued}
    else
      nil -> {:error, :missing_merge_candidate}
      {:error, reason} -> {:error, reason}
    end
  end

  def allowed_transition?(from, to), do: Vela.StateMachine.allowed?(:merge_candidate, from, to)
  def transitions, do: Vela.StateMachine.transitions(:merge_candidate)

  defp attrs_with_target_branch(pull_request_id, attrs) do
    case {Map.has_key?(attrs, :target_branch), Map.has_key?(attrs, "target_branch")} do
      {false, false} ->
        pull_request_id
        |> Repo.get(Vela.Forge.PullRequest)
        |> case do
          nil -> attrs
          pull_request -> Map.put(attrs, :target_branch, pull_request.target_branch)
        end

      _ ->
        attrs
    end
  end

  defp queue_attrs(%MergeCandidate{} = candidate, %Vela.Forge.PullRequest{} = pull_request) do
    attrs = %{target_branch: pull_request.target_branch}

    if candidate.queue_position do
      attrs
    else
      Map.put(
        attrs,
        :queue_position,
        next_queue_position(pull_request.repository_id, pull_request.target_branch)
      )
    end
  end

  defp next_queue_position(repository_id, target_branch) do
    MergeCandidate
    |> where([c], c.repository_id == ^repository_id)
    |> where([c], c.target_branch == ^target_branch)
    |> where([c], c.status in ^@queue_statuses)
    |> select([c], max(c.queue_position))
    |> Repo.one()
    |> case do
      nil -> 1
      position -> position + 1
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
