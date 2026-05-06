defmodule Vela.Jobs.RepositoryJobs do
  @moduledoc """
  Oban constructors for repository import and synchronization work.
  """

  @workers %{
    repo_import: Vela.Jobs.RepoImportWorker,
    repo_sync: Vela.Jobs.RepoSyncWorker
  }

  def kinds, do: Map.keys(@workers)
  def workers, do: @workers
  def worker(kind), do: Map.fetch(@workers, kind)
end
