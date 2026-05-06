defmodule Vela.Maestro do
  @moduledoc """
  Local deterministic Phase 0 readiness scoring plus persisted analysis records.
  """

  alias Vela.Maestro.{AnalysisRun, LaunchReadinessScore, ReadinessScore, ScoringProfiles}
  alias Vela.Repo

  def create_analysis_run(attrs),
    do: %AnalysisRun{} |> AnalysisRun.changeset(attrs) |> Repo.insert()

  def update_analysis_run(%AnalysisRun{} = analysis_run, attrs),
    do: analysis_run |> AnalysisRun.changeset(attrs) |> Repo.update()

  def create_launch_readiness_score(attrs),
    do: %LaunchReadinessScore{} |> LaunchReadinessScore.changeset(attrs) |> Repo.insert()

  def create_readiness_score(attrs),
    do: %ReadinessScore{} |> ReadinessScore.changeset(attrs) |> Repo.insert()

  def compute_readiness(%{dimensions: dimensions} = attrs) do
    confidence = Map.get(attrs, :confidence, "medium")
    score = dimensions |> Map.values() |> Enum.sum() |> div(map_size(dimensions))

    verdict =
      cond do
        Enum.any?(
          ["security", "test_evidence", "repository_trust"],
          &(Map.get(dimensions, &1, 0) < 50)
        ) ->
          "block"

        confidence == "low" or score < 75 ->
          "wait"

        true ->
          "ship"
      end

    %{score: score, verdict: verdict, confidence: confidence, dimensions: dimensions}
  end

  def compute_readiness_score(attrs) do
    profile = Map.get(attrs, :repo_profile, :default)
    blocking_findings = Map.get(attrs, :blocking_findings, [])
    confidence = Map.get(attrs, :confidence, "high")
    overall = ScoringProfiles.weighted_score(attrs, profile)

    verdict =
      cond do
        blocking_findings != [] -> "block"
        Map.get(attrs, :security_score, 0) < 60 -> "block"
        Map.get(attrs, :correctness_score, 0) < 60 -> "block"
        confidence == "low" -> "wait"
        overall < 75 -> "wait"
        true -> "ship"
      end

    Map.merge(attrs, %{overall_score: overall, verdict: verdict, confidence: confidence})
  end

  def default_weights, do: ScoringProfiles.default_weights()
  def profile_weights(profile), do: ScoringProfiles.profile_weights(profile)
end
