defmodule Vela.Merge.MergeCandidate do
  use Vela.Schema

  @statuses ~w(pending simulating testing blocked ready merging merged failed cancelled)

  schema "merge_candidates" do
    field :base_sha, :string
    field :head_sha, :string
    field :virtual_merge_sha, :string
    field :virtual_merge_tree_hash, :string
    field :tested_tree_hash, :string
    field :final_merge_tree_hash, :string
    field :status, :string
    field :queue_position, :integer
    field :policy_result, :map, default: %{}
    field :rollback_plan, :map, default: %{}

    belongs_to :repository, Vela.Forge.Repository
    belongs_to :pull_request, Vela.Forge.PullRequest
    belongs_to :analysis_run, Vela.Maestro.AnalysisRun

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, [
      :repository_id,
      :pull_request_id,
      :base_sha,
      :head_sha,
      :virtual_merge_sha,
      :virtual_merge_tree_hash,
      :tested_tree_hash,
      :final_merge_tree_hash,
      :status,
      :queue_position,
      :analysis_run_id,
      :policy_result,
      :rollback_plan
    ])
    |> validate_required([:repository_id, :pull_request_id, :base_sha, :head_sha, :status])
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_tree_equivalence()
  end

  defp validate_tree_equivalence(changeset) do
    status = get_field(changeset, :status)
    tested = get_field(changeset, :tested_tree_hash)
    final = get_field(changeset, :final_merge_tree_hash)

    if (status in ["ready", "merged"] and final) && tested != final do
      add_error(changeset, :final_merge_tree_hash, "must match tested_tree_hash")
    else
      changeset
    end
  end
end
