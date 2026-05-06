defmodule Vela.Repo.Migrations.CreateVelaControlPlane do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :plan, :string, null: false, default: "free"
      add :workos_org_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:slug])
    create unique_index(:organizations, [:workos_org_id], where: "workos_org_id IS NOT NULL")

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string, null: false
      add :avatar_url, :string
      add :workos_user_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:workos_user_id], where: "workos_user_id IS NOT NULL")

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:memberships, [:organization_id, :user_id])
    create index(:memberships, [:organization_id])
    create index(:memberships, [:user_id])

    create table(:actors, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :type, :string, null: false
      add :display_name, :string, null: false
      add :trust_level, :string, null: false, default: "unverified"
      add :external_ref, :string
      add :signing_key_ref, :string
      add :created_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:actors, [:organization_id])
    create index(:actors, [:type])

    create table(:agent_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :actor_id, references(:actors, type: :binary_id, on_delete: :delete_all), null: false
      add :did, :string
      add :public_key, :text
      add :trust_score, :integer, null: false, default: 0

      add :issuer_organization_id,
          references(:organizations, type: :binary_id, on_delete: :nilify_all)

      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:agent_identities, [:actor_id])
    create unique_index(:agent_identities, [:did], where: "did IS NOT NULL")

    create table(:repositories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :slug, :string, null: false
      add :visibility, :string, null: false, default: "private"
      add :default_branch, :string, null: false, default: "main"
      add :description, :text
      add :repo_cell_id, :string
      add :health_status, :string, null: false, default: "healthy"
      add :risk_level, :string, null: false, default: "low"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:repositories, [:organization_id, :slug])
    create index(:repositories, [:organization_id])

    create table(:branches, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :current_sha, :string, null: false
      add :protected, :boolean, null: false, default: false
      add :leased_by_agent_session_id, :binary_id

      timestamps(type: :utc_datetime)
    end

    create unique_index(:branches, [:repository_id, :name])
    create index(:branches, [:repository_id])

    create table(:pull_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :author_actor_id, references(:actors, type: :binary_id, on_delete: :restrict),
        null: false

      add :title, :string, null: false
      add :description, :text
      add :source_branch, :string, null: false
      add :target_branch, :string, null: false
      add :head_sha, :string, null: false
      add :base_sha, :string, null: false
      add :status, :string, null: false
      add :intent, :text
      add :behavioral_summary, :text
      add :risk_level, :string, null: false, default: "medium"
      add :readiness_score_id, :binary_id
      add :merge_candidate_id, :binary_id

      timestamps(type: :utc_datetime)
    end

    create index(:pull_requests, [:repository_id])
    create index(:pull_requests, [:author_actor_id])
    create index(:pull_requests, [:status])

    create table(:reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:actors, type: :binary_id, on_delete: :restrict), null: false
      add :status, :string, null: false
      add :summary, :text

      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:pull_request_id])
    create index(:reviews, [:actor_id])

    create table(:issues, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :author_actor_id, references(:actors, type: :binary_id, on_delete: :restrict),
        null: false

      add :title, :string, null: false
      add :body, :text
      add :status, :string, null: false, default: "open"
      add :priority, :string, null: false, default: "medium"
      add :labels, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:issues, [:repository_id])
    create index(:issues, [:status])

    create table(:agent_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :agent_actor_id, references(:actors, type: :binary_id, on_delete: :restrict),
        null: false

      add :human_supervisor_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :branch_id, references(:branches, type: :binary_id, on_delete: :nilify_all)
      add :task_intent, :text, null: false
      add :prompt_hash, :string
      add :model, :string
      add :toolchain, :map, null: false, default: %{}
      add :status, :string, null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:agent_sessions, [:organization_id])
    create index(:agent_sessions, [:repository_id])
    create index(:agent_sessions, [:agent_actor_id])
    create index(:agent_sessions, [:status])

    create table(:analysis_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :delete_all),
        null: false

      add :commit_sha, :string, null: false
      add :status, :string, null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :summary, :text

      timestamps(type: :utc_datetime)
    end

    create index(:analysis_runs, [:organization_id])
    create index(:analysis_runs, [:repository_id])
    create index(:analysis_runs, [:pull_request_id])
    create index(:analysis_runs, [:status])

    create table(:launch_readiness_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :analysis_run_id, references(:analysis_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :delete_all),
        null: false

      add :overall_score, :integer, null: false
      add :verdict, :string, null: false
      add :confidence, :string, null: false
      add :behavioral_score, :integer, null: false
      add :correctness_score, :integer, null: false
      add :security_score, :integer, null: false
      add :performance_score, :integer, null: false
      add :ux_score, :integer, null: false
      add :test_evidence_score, :integer, null: false
      add :rollback_score, :integer, null: false
      add :agent_provenance_score, :integer, null: false
      add :explanation, :text, null: false
      add :blocking_findings, {:array, :map}, null: false, default: []
      add :required_actions, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:launch_readiness_scores, [:analysis_run_id])
    create index(:launch_readiness_scores, [:pull_request_id])
    create index(:launch_readiness_scores, [:verdict])

    create table(:merge_candidates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :delete_all),
        null: false

      add :base_sha, :string, null: false
      add :head_sha, :string, null: false
      add :virtual_merge_sha, :string
      add :virtual_merge_tree_hash, :string
      add :tested_tree_hash, :string
      add :final_merge_tree_hash, :string
      add :status, :string, null: false
      add :queue_position, :integer
      add :analysis_run_id, references(:analysis_runs, type: :binary_id, on_delete: :nilify_all)
      add :policy_result, :map, null: false, default: %{}
      add :rollback_plan, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:merge_candidates, [:repository_id])
    create index(:merge_candidates, [:pull_request_id])
    create index(:merge_candidates, [:status])

    create table(:evidence_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :nilify_all)
      add :actor_id, references(:actors, type: :binary_id, on_delete: :restrict), null: false
      add :event_type, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id
      add :payload, :map, null: false, default: %{}
      add :payload_hash, :string, null: false
      add :prev_event_hash, :string
      add :event_hash, :string, null: false
      add :signature, :text

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:evidence_events, [:organization_id, :inserted_at])
    create index(:evidence_events, [:repository_id, :inserted_at])
    create index(:evidence_events, [:actor_id, :inserted_at])
    create index(:evidence_events, [:event_type])
    create unique_index(:evidence_events, [:event_hash])

    create table(:agent_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:actors, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :allowed_repos, {:array, :string}, null: false, default: []
      add :allowed_branches, {:array, :string}, null: false, default: []
      add :allowed_paths, {:array, :string}, null: false, default: []
      add :forbidden_paths, {:array, :string}, null: false, default: []
      add :max_pr_size, :integer
      add :requires_human_approval, :boolean, null: false, default: true
      add :can_merge, :boolean, null: false, default: false
      add :can_deploy, :boolean, null: false, default: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:agent_policies, [:organization_id])
    create index(:agent_policies, [:actor_id])

    create table(:runners, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :type, :string, null: false
      add :labels, {:array, :string}, null: false, default: []
      add :status, :string, null: false
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:runners, [:organization_id])
    create index(:runners, [:status])

    create table(:pipeline_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :nilify_all)
      add :commit_sha, :string, null: false
      add :status, :string, null: false
      add :score_impact, :integer
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:pipeline_runs, [:repository_id])
    create index(:pipeline_runs, [:pull_request_id])
    create index(:pipeline_runs, [:status])

    create table(:pipeline_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :pipeline_run_id, references(:pipeline_runs, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :command, :text, null: false
      add :sandbox_config, :map, null: false, default: %{}
      add :logs_ref, :string
      add :artifacts_ref, :string
      add :status, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:pipeline_jobs, [:pipeline_run_id])
    create index(:pipeline_jobs, [:status])
  end
end
