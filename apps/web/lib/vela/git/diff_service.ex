defmodule Vela.Git.DiffService do
  @moduledoc "Sidecar boundary for diff and changed-path analysis."

  @callback diff(map()) :: {:ok, map()} | {:error, term()}
  @callback changed_paths(map()) :: {:ok, list(String.t())} | {:error, term()}
end
