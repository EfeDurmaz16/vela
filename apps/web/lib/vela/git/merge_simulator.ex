defmodule Vela.Git.MergeSimulator do
  @moduledoc "Sidecar boundary for deterministic virtual merge simulation."

  @callback simulate(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_tree_equivalence(map()) :: :ok | {:error, term()}
end
