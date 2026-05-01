defmodule Vela.MaestroTest do
  use ExUnit.Case, async: true

  alias Vela.Maestro

  test "ships when weighted score is high and no blockers exist" do
    result =
      Maestro.compute_readiness_score(%{
        behavioral_score: 90,
        correctness_score: 85,
        security_score: 80,
        performance_score: 82,
        ux_score: 88,
        test_evidence_score: 80,
        rollback_score: 70,
        agent_provenance_score: 78,
        confidence: "high",
        blocking_findings: []
      })

    assert result.verdict == "ship"
    assert result.overall_score >= 75
  end

  test "blocks on blocking findings or weak critical dimensions" do
    blocked =
      Maestro.compute_readiness_score(%{
        behavioral_score: 90,
        correctness_score: 90,
        security_score: 90,
        performance_score: 90,
        ux_score: 90,
        test_evidence_score: 90,
        agent_provenance_score: 90,
        confidence: "high",
        blocking_findings: [%{"message" => "secret leak"}]
      })

    weak_security =
      Maestro.compute_readiness_score(
        Map.put(blocked, :blocking_findings, [])
        |> Map.put(:security_score, 59)
      )

    assert blocked.verdict == "block"
    assert weak_security.verdict == "block"
  end

  test "uses repo-specific weighting profiles" do
    assert Maestro.profile_weights(:payments_or_auth).security_score == 30
    assert Maestro.profile_weights(:frontend).ux_score == 30
    assert Maestro.profile_weights(:infrastructure).rollback_score == 20
  end
end
