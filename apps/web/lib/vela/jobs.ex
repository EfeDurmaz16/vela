defmodule Vela.Jobs do
  @moduledoc """
  Oban job constructors for expensive request-path work.
  """

  @workers %{
    repo_import: Vela.Jobs.RepoImportWorker,
    analysis_run: Vela.Jobs.AnalysisRunWorker,
    readiness_score: Vela.Jobs.ReadinessScoreWorker,
    trust_score: Vela.Jobs.TrustScoreWorker,
    repo_sync: Vela.Jobs.RepoSyncWorker,
    merge_simulation: Vela.Jobs.MergeSimulationWorker
  }

  def new(kind, attrs) when is_atom(kind) do
    worker = Map.fetch!(@workers, kind)
    args = attrs |> stringify_keys() |> Map.put("kind", to_string(kind))
    worker.new(args)
  end

  def enqueue(kind, attrs), do: kind |> new(attrs) |> Oban.insert()

  def workers, do: @workers

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
