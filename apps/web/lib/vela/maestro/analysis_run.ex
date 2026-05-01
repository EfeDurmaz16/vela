defmodule Vela.Maestro.AnalysisRun do
  use Vela.Schema

  @statuses ~w(queued running completed failed cancelled)

  schema "analysis_runs" do
    field :commit_sha, :string
    field :status, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :summary, :string

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :pull_request, Vela.Forge.PullRequest
    has_one :readiness_score, Vela.Maestro.LaunchReadinessScore

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :pull_request_id,
      :commit_sha,
      :status,
      :started_at,
      :completed_at,
      :summary
    ])
    |> validate_required([
      :organization_id,
      :repository_id,
      :pull_request_id,
      :commit_sha,
      :status
    ])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
  end
end
