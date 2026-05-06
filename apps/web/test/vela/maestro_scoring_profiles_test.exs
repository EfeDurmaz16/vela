defmodule Vela.Maestro.ScoringProfilesTest do
  use ExUnit.Case, async: true

  alias Vela.Maestro
  alias Vela.Maestro.ScoringProfiles

  test "unknown profiles fall back to default weights" do
    assert ScoringProfiles.profile_weights(:unknown) == ScoringProfiles.default_weights()
  end

  test "weighted_score treats missing dimensions as zero" do
    score =
      ScoringProfiles.weighted_score(
        %{
          behavioral_score: 100,
          correctness_score: 100,
          security_score: 100
        },
        :default
      )

    assert score == 60
  end

  test "compute_readiness_score waits on low confidence even with high weighted score" do
    result =
      Maestro.compute_readiness_score(%{
        behavioral_score: 95,
        correctness_score: 95,
        security_score: 95,
        performance_score: 95,
        ux_score: 95,
        test_evidence_score: 95,
        rollback_score: 95,
        agent_provenance_score: 95,
        confidence: "low",
        blocking_findings: []
      })

    assert result.overall_score == 95
    assert result.verdict == "wait"
  end

  test "infrastructure profile includes rollback score in weighting" do
    result =
      Maestro.compute_readiness_score(%{
        repo_profile: :infrastructure,
        behavioral_score: 100,
        correctness_score: 100,
        security_score: 100,
        performance_score: 100,
        rollback_score: 0,
        confidence: "high",
        blocking_findings: []
      })

    assert result.overall_score == 80
    assert result.verdict == "ship"
  end
end
