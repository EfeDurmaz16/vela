defmodule Vela.Jobs.MergeJobs do
  @moduledoc """
  Oban constructors for merge simulation work.
  """

  @workers %{
    merge_simulation: Vela.Jobs.MergeSimulationWorker
  }

  def kinds, do: Map.keys(@workers)
  def workers, do: @workers
  def worker(kind), do: Map.fetch(@workers, kind)
end
