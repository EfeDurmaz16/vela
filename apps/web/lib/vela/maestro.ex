defmodule Vela.Maestro do
  @moduledoc """
  Local deterministic Phase 0 readiness scoring plus persisted analysis records.
  """

  alias Vela.Maestro.{AnalysisRun, LaunchReadinessScore, ReadinessScore}
  alias Vela.Repo

  @default_weights %{
    behavioral_score: 20,
    correctness_score: 20,
    security_score: 20,
    performance_score: 15,
    ux_score: 10,
    test_evidence_score: 10,
    agent_provenance_score: 5
  }

  @profiles %{
    payments_or_auth: %{
      security_score: 30,
      correctness_score: 30,
      behavioral_score: 20,
      performance_score: 10,
      ux_score: 5,
      agent_provenance_score: 5
    },
    frontend: %{
      ux_score: 30,
      behavioral_score: 25,
      correctness_score: 20,
      performance_score: 15,
      security_score: 5,
      agent_provenance_score: 5
    },
    infrastructure: %{
      correctness_score: 30,
      performance_score: 25,
      rollback_score: 20,
      security_score: 15,
      behavioral_score: 10
    }
  }

  def create_analysis_run(attrs),
    do: %AnalysisRun{} |> AnalysisRun.changeset(attrs) |> Repo.insert()

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
    weights = Map.get(@profiles, profile, @default_weights)
    blocking_findings = Map.get(attrs, :blocking_findings, [])
    confidence = Map.get(attrs, :confidence, "high")
    overall = weighted_score(attrs, weights)

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

  def default_weights, do: @default_weights
  def profile_weights(profile), do: Map.get(@profiles, profile, @default_weights)

  defp weighted_score(attrs, weights) do
    total_weight = weights |> Map.values() |> Enum.sum()

    weighted_total =
      Enum.reduce(weights, 0, fn {field, weight}, acc ->
        acc + Map.get(attrs, field, 0) * weight
      end)

    round(weighted_total / total_weight)
  end
end
