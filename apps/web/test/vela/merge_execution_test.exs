defmodule Vela.MergeExecutionTest do
  use ExUnit.Case, async: true

  alias Vela.Merge.Execution
  alias Vela.Merge.MergeCandidate

  defmodule SuccessAdapter do
    @behaviour Vela.Merge.ExecutionAdapter

    @impl true
    def execute(request) do
      {:ok,
       %{
         merge_sha: "#{request.head_sha}-merged",
         merge_tree_hash: request.expected_tree_hash,
         provider: "fake",
         metadata: %{request_metadata: request.metadata}
       }}
    end
  end

  defmodule FailureAdapter do
    @behaviour Vela.Merge.ExecutionAdapter

    @impl true
    def execute(_request), do: {:error, :provider_denied}
  end

  test "builds execution requests from merge candidates" do
    candidate = candidate()

    assert %{
             merge_candidate_id: candidate_id,
             repository_id: repository_id,
             pull_request_id: pull_request_id,
             base_sha: "base",
             head_sha: "head",
             target_branch: "main",
             expected_tree_hash: "tree:tested",
             metadata: %{actor_id: "actor-1"}
           } = Execution.build_request(candidate, metadata: %{actor_id: "actor-1"})

    assert candidate_id == candidate.id
    assert repository_id == candidate.repository_id
    assert pull_request_id == candidate.pull_request_id
  end

  test "normalizes successful adapter results" do
    assert {:ok,
            %{
              merge_sha: "head-merged",
              merge_tree_hash: "tree:tested",
              provider: "fake",
              metadata: %{request_metadata: %{actor_id: "actor-1"}}
            }} = Execution.execute(candidate(), SuccessAdapter, metadata: %{actor_id: "actor-1"})
  end

  test "passes adapter failures through and rejects malformed success results" do
    assert {:error, :provider_denied} = Execution.execute(candidate(), FailureAdapter)
    assert {:error, :missing_merge_sha} = Execution.normalize_result(%{merge_tree_hash: "tree"})
    assert {:error, :invalid_merge_result} = Execution.normalize_result(:ok)
  end

  defp candidate do
    %MergeCandidate{
      id: Ecto.UUID.generate(),
      repository_id: Ecto.UUID.generate(),
      pull_request_id: Ecto.UUID.generate(),
      base_sha: "base",
      head_sha: "head",
      target_branch: "main",
      tested_tree_hash: "tree:tested",
      status: "queued"
    }
  end
end
