defmodule Vela.Maestro.LaunchReadinessScore do
  use Vela.Schema

  @verdicts ~w(ship wait block)
  @confidences ~w(low medium high)

  schema "launch_readiness_scores" do
    field :overall_score, :integer
    field :verdict, :string
    field :confidence, :string
    field :behavioral_score, :integer
    field :correctness_score, :integer
    field :security_score, :integer
    field :performance_score, :integer
    field :ux_score, :integer
    field :test_evidence_score, :integer
    field :rollback_score, :integer
    field :agent_provenance_score, :integer
    field :explanation, :string
    field :blocking_findings, {:array, :map}, default: []
    field :required_actions, {:array, :string}, default: []

    belongs_to :analysis_run, Vela.Maestro.AnalysisRun
    belongs_to :pull_request, Vela.Forge.PullRequest

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def verdicts, do: @verdicts

  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :analysis_run_id,
      :pull_request_id,
      :overall_score,
      :verdict,
      :confidence,
      :behavioral_score,
      :correctness_score,
      :security_score,
      :performance_score,
      :ux_score,
      :test_evidence_score,
      :rollback_score,
      :agent_provenance_score,
      :explanation,
      :blocking_findings,
      :required_actions
    ])
    |> validate_required([
      :analysis_run_id,
      :pull_request_id,
      :overall_score,
      :verdict,
      :confidence,
      :behavioral_score,
      :correctness_score,
      :security_score,
      :performance_score,
      :ux_score,
      :test_evidence_score,
      :rollback_score,
      :agent_provenance_score,
      :explanation
    ])
    |> Vela.Validation.validate_inclusion(:verdict, @verdicts)
    |> Vela.Validation.validate_inclusion(:confidence, @confidences)
    |> validate_scores()
  end

  defp validate_scores(changeset) do
    Enum.reduce(
      [
        :overall_score,
        :behavioral_score,
        :correctness_score,
        :security_score,
        :performance_score,
        :ux_score,
        :test_evidence_score,
        :rollback_score,
        :agent_provenance_score
      ],
      changeset,
      &Vela.Validation.validate_score(&2, &1)
    )
  end
end
