defmodule Vela.Git.RefService do
  @moduledoc "Sidecar boundary for branch/ref reads and leases."

  @callback list_refs(map()) :: {:ok, list(map())} | {:error, term()}
  @callback resolve_ref(map()) :: {:ok, map()} | {:error, term()}
  @callback lease_ref(map()) :: {:ok, map()} | {:error, term()}
end
