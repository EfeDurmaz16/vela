defmodule Vela.Git.GitProvider do
  @moduledoc "Adapter contract for GitHub and future Git providers."

  @callback import_repository(map()) :: {:ok, map()} | {:error, term()}
  @callback mirror_repository(map()) :: {:ok, map()} | {:error, term()}
  @callback fetch_pull_request(map()) :: {:ok, map()} | {:error, term()}
end
