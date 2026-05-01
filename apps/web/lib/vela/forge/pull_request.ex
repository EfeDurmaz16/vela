defmodule Vela.Forge.PullRequest do
  use Vela.Schema

  @statuses ~w(draft open ready_for_review blocked approved queued merged closed)
  @risk_levels ~w(low medium high critical)

  schema "pull_requests" do
    field :title, :string
    field :description, :string
    field :source_branch, :string
    field :target_branch, :string
    field :head_sha, :string
    field :base_sha, :string
    field :status, :string
    field :intent, :string
    field :behavioral_summary, :string
    field :risk_level, :string, default: "medium"
    field :readiness_score_id, :binary_id
    field :merge_candidate_id, :binary_id

    belongs_to :repository, Vela.Forge.Repository
    belongs_to :author_actor, Vela.Actors.Actor
    has_many :reviews, Vela.Forge.Review
    has_many :analysis_runs, Vela.Maestro.AnalysisRun
    has_many :readiness_scores, Vela.Maestro.LaunchReadinessScore
    has_many :merge_candidates, Vela.Merge.MergeCandidate

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(pr, attrs) do
    pr
    |> cast(attrs, [
      :repository_id,
      :author_actor_id,
      :title,
      :description,
      :source_branch,
      :target_branch,
      :head_sha,
      :base_sha,
      :status,
      :intent,
      :behavioral_summary,
      :risk_level,
      :readiness_score_id,
      :merge_candidate_id
    ])
    |> validate_required([
      :repository_id,
      :author_actor_id,
      :title,
      :source_branch,
      :target_branch,
      :head_sha,
      :base_sha,
      :status
    ])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> Vela.Validation.validate_inclusion(:risk_level, @risk_levels)
  end
end
