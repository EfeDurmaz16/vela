defmodule Vela.Maestro.ScoringProfiles do
  @moduledoc """
  Weighted readiness scoring profiles for launch readiness decisions.
  """

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

  def default_weights, do: @default_weights
  def profile_weights(profile), do: Map.get(@profiles, profile, @default_weights)

  def weighted_score(attrs, profile) do
    weights = profile_weights(profile)
    total_weight = weights |> Map.values() |> Enum.sum()

    weighted_total =
      Enum.reduce(weights, 0, fn {field, weight}, acc ->
        acc + Map.get(attrs, field, 0) * weight
      end)

    round(weighted_total / total_weight)
  end
end
