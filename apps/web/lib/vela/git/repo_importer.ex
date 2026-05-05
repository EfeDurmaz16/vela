defmodule Vela.Git.RepoImporter do
  @moduledoc "Sidecar boundary for repository import work."

  @callback enqueue_import(map()) :: {:ok, map()} | {:error, term()}
  @callback import_snapshot(map()) :: {:ok, map()} | {:error, term()}
end
