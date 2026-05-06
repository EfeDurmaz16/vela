defmodule Vela.Merge.Gates do
  @moduledoc """
  Merge queue gates that must pass before a candidate can be queued.
  """

  import Ecto.Query

  alias Vela.Forge.{Branch, CheckRun, PullRequest, Review}
  alias Vela.Repo

  def review_gate(pull_request_id) do
    reviews =
      Review
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

  def branch_protection_gate(%PullRequest{} = pull_request) do
    case protected_branch(pull_request) do
      %Branch{protected: true} = branch ->
        with :ok <- required_approval_gate(pull_request.id, branch.required_approvals),
             :ok <- required_checks_gate(pull_request.id, branch.required_checks) do
          :ok
        end

      _branch ->
        :ok
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

  defp protected_branch(%PullRequest{} = pull_request) do
    Branch
    |> where([b], b.repository_id == ^pull_request.repository_id)
    |> where([b], b.name == ^pull_request.target_branch)
    |> Repo.one()
  end

  defp required_approval_gate(_pull_request_id, required_approvals)
       when required_approvals in [nil, 0],
       do: :ok

  defp required_approval_gate(pull_request_id, required_approvals) do
    approval_count =
      Review
      |> where([r], r.pull_request_id == ^pull_request_id and r.status == "approve")
      |> Repo.aggregate(:count)

    if approval_count >= required_approvals do
      :ok
    else
      {:error, :branch_protection_missing_approvals}
    end
  end

  defp required_checks_gate(_pull_request_id, required_checks)
       when required_checks in [nil, []],
       do: :ok

  defp required_checks_gate(pull_request_id, required_checks) do
    successful_checks =
      CheckRun
      |> where([c], c.pull_request_id == ^pull_request_id)
      |> where([c], c.status == "completed" and c.conclusion == "success")
      |> select([c], c.name)
      |> Repo.all()
      |> MapSet.new()

    if Enum.all?(required_checks, &MapSet.member?(successful_checks, &1)) do
      :ok
    else
      {:error, :branch_protection_missing_checks}
    end
  end
end
