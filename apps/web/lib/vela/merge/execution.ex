defmodule Vela.Merge.Execution do
  @moduledoc """
  Builds and normalizes final merge execution requests.

  This module intentionally does not perform a real merge yet. It is the local
  contract between Vela's deterministic queue state and future forge-specific
  execution adapters.
  """

  alias Vela.Merge.MergeCandidate

  def execute(%MergeCandidate{} = candidate, adapter, attrs \\ []) when is_atom(adapter) do
    request = build_request(candidate, attrs)

    with {:ok, result} <- adapter.execute(request),
         {:ok, normalized} <- normalize_result(result) do
      {:ok, normalized}
    end
  end

  def build_request(%MergeCandidate{} = candidate, attrs \\ []) do
    metadata = attrs |> Map.new() |> Map.get(:metadata, %{})

    %{
      merge_candidate_id: candidate.id,
      repository_id: candidate.repository_id,
      pull_request_id: candidate.pull_request_id,
      base_sha: candidate.base_sha,
      head_sha: candidate.head_sha,
      target_branch: candidate.target_branch,
      expected_tree_hash: candidate.tested_tree_hash,
      metadata: metadata
    }
  end

  def normalize_result(result) when is_map(result) do
    merge_sha = fetch(result, :merge_sha)

    if present?(merge_sha) do
      {:ok,
       %{
         merge_sha: merge_sha,
         merge_tree_hash: fetch(result, :merge_tree_hash),
         provider: fetch(result, :provider),
         metadata: fetch(result, :metadata) || %{}
       }}
    else
      {:error, :missing_merge_sha}
    end
  end

  def normalize_result(_result), do: {:error, :invalid_merge_result}

  defp fetch(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
