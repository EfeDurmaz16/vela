defmodule Vela.ReadinessScoreTest do
  use Vela.DataCase, async: true

  alias Vela.Maestro
  alias Vela.Maestro.ReadinessScore

  @valid_attrs %{
    organization_id: Ecto.UUID.generate(),
    repository_id: Ecto.UUID.generate(),
    change_id: Ecto.UUID.generate(),
    analysis_run_id: Ecto.UUID.generate(),
    score: 84,
    verdict: "ship",
    confidence: "high",
    dimensions: %{
      "repository_trust" => 88,
      "change_risk" => 78,
      "test_evidence" => 82,
      "security" => 86,
      "performance" => 80,
      "agent_provenance" => 90,
      "launch_readiness" => 84
    },
    explanation: "Repository trust, tests, security, and launch evidence are within bounds.",
    evidence_refs: [Ecto.UUID.generate()]
  }

  test "validates the objective readiness dimensions and score bounds" do
    assert %{valid?: true} = ReadinessScore.changeset(%ReadinessScore{}, @valid_attrs)

    missing_dimension = put_in(@valid_attrs, [:dimensions, "security"], nil)
    assert %{valid?: false} = ReadinessScore.changeset(%ReadinessScore{}, missing_dimension)

    bad_score = Map.put(@valid_attrs, :score, 101)
    assert %{valid?: false} = ReadinessScore.changeset(%ReadinessScore{}, bad_score)
  end

  test "requires useful dimension explanations for non-ship verdicts" do
    wait_attrs =
      @valid_attrs
      |> Map.put(:verdict, "wait")
      |> Map.put(:dimension_explanations, %{"security" => "too short"})

    changeset = ReadinessScore.changeset(%ReadinessScore{}, wait_attrs)

    refute changeset.valid?

    assert Enum.any?(changeset.errors, fn
             {:dimension_explanations, {message, _opts}} ->
               String.contains?(message, "repository_trust explanation is required")

             _error ->
               false
           end)

    defaulted =
      @valid_attrs
      |> Map.put(:verdict, "block")
      |> Map.delete(:dimension_explanations)
      |> then(&ReadinessScore.changeset(%ReadinessScore{}, &1))

    assert defaulted.valid?

    assert Ecto.Changeset.get_change(defaulted, :dimension_explanations)["security"] =~
             "Security contributed"
  end

  test "computes verdicts from objective readiness dimensions" do
    ship = Maestro.compute_readiness(%{dimensions: @valid_attrs.dimensions, confidence: "high"})
    wait = Maestro.compute_readiness(%{dimensions: @valid_attrs.dimensions, confidence: "low"})

    block =
      Maestro.compute_readiness(%{dimensions: Map.put(@valid_attrs.dimensions, "security", 40)})

    assert ship.verdict == "ship"
    assert wait.verdict == "wait"
    assert block.verdict == "block"
  end
end
