defmodule Vela.Jobs.ScoringJobs do
  @moduledoc """
  Oban constructors for readiness and trust scoring work.
  """

  @workers %{
    readiness_score: Vela.Jobs.ReadinessScoreWorker,
    score_recalculation: Vela.Jobs.ScoreRecalculationWorker,
    trust_score: Vela.Jobs.TrustScoreWorker
  }

  def kinds, do: Map.keys(@workers)
  def workers, do: @workers
  def worker(kind), do: Map.fetch(@workers, kind)
end
