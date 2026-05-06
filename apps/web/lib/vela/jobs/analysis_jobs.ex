defmodule Vela.Jobs.AnalysisJobs do
  @moduledoc """
  Oban constructors for analysis orchestration work.
  """

  @workers %{
    analysis_run: Vela.Jobs.AnalysisRunWorker
  }

  def kinds, do: Map.keys(@workers)
  def workers, do: @workers
  def worker(kind), do: Map.fetch(@workers, kind)
end
