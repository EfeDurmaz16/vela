defmodule Vela.Pipelines.PipelineRun do
  use Vela.Schema

  schema "pipeline_runs" do
    field :commit_sha, :string
    field :status, :string
    field :score_impact, :integer
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :repository, Vela.Forge.Repository
    belongs_to :pull_request, Vela.Forge.PullRequest
    has_many :jobs, Vela.Pipelines.PipelineJob

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :repository_id,
      :pull_request_id,
      :commit_sha,
      :status,
      :score_impact,
      :started_at,
      :completed_at
    ])
    |> validate_required([:repository_id, :commit_sha, :status])
  end
end
