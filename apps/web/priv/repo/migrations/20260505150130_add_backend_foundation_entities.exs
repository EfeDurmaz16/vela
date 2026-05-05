defmodule Vela.Repo.Migrations.AddBackendFoundationEntities do
  use Ecto.Migration

  def change do
    create table(:changes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :author_actor_id, references(:actors, type: :binary_id, on_delete: :restrict),
        null: false

      add :title, :string, null: false
      add :description, :text
      add :source_ref, :string
      add :target_ref, :string
      add :head_sha, :string
      add :base_sha, :string
      add :status, :string, null: false, default: "draft"
      add :risk_level, :string, null: false, default: "medium"
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:changes, [:organization_id, :status, :inserted_at])
    create index(:changes, [:repository_id, :status, :inserted_at])
    create index(:changes, [:author_actor_id, :inserted_at])

    create table(:readiness_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :change_id, references(:changes, type: :binary_id, on_delete: :nilify_all)
      add :analysis_run_id, references(:analysis_runs, type: :binary_id, on_delete: :nilify_all)
      add :score, :integer, null: false
      add :verdict, :string, null: false
      add :confidence, :string, null: false
      add :dimensions, :map, null: false
      add :explanation, :text, null: false
      add :evidence_refs, {:array, :binary_id}, null: false, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:readiness_scores, [:organization_id, :verdict, :inserted_at])
    create index(:readiness_scores, [:repository_id, :inserted_at])
    create index(:readiness_scores, [:change_id])
    create index(:readiness_scores, [:analysis_run_id])

    create table(:release_candidates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :merge_candidate_id,
          references(:merge_candidates, type: :binary_id, on_delete: :nilify_all)

      add :created_by_actor_id, references(:actors, type: :binary_id, on_delete: :restrict)
      add :version, :string, null: false
      add :environment, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :artifact_ref, :string
      add :rollback_plan, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:release_candidates, [:repository_id, :version, :environment])
    create index(:release_candidates, [:organization_id, :status, :inserted_at])
    create index(:release_candidates, [:repository_id, :status, :inserted_at])

    create table(:integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :config, :map, null: false, default: %{}
      add :token_ciphertext, :text
      add :external_ref, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:integrations, [:organization_id, :provider, :name])
    create index(:integrations, [:organization_id, :provider, :status])

    create table(:environments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :type, :string, null: false, default: "preview"
      add :status, :string, null: false, default: "active"
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:environments, [:repository_id, :name])
    create index(:environments, [:organization_id, :status])

    create table(:service_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :environment_id, references(:environments, type: :binary_id, on_delete: :nilify_all)
      add :service_name, :string, null: false
      add :service_type, :string, null: false
      add :status, :string, null: false, default: "active"
      add :external_ref, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:service_connections, [:organization_id, :status])
    create index(:service_connections, [:repository_id, :service_type, :status])
    create index(:service_connections, [:integration_id])

    create table(:repository_trust_signals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :source, :string, null: false
      add :signal_type, :string, null: false
      add :score, :integer, null: false
      add :confidence, :string, null: false, default: "medium"
      add :payload, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:repository_trust_signals, [:organization_id, :signal_type, :inserted_at])
    create index(:repository_trust_signals, [:repository_id, :signal_type, :inserted_at])

    create table(:idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :actor_id, references(:actors, type: :binary_id, on_delete: :nilify_all)
      add :request_hash, :string, null: false
      add :response_status, :integer
      add :response_body, :map
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:idempotency_keys, [:organization_id, :key])
    create index(:idempotency_keys, [:expires_at])

    create table(:outbox_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :status, :string, null: false, default: "pending"
      add :attempts, :integer, null: false, default: 0
      add :locked_at, :utc_datetime
      add :published_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:outbox_events, [:organization_id, :status, :inserted_at])
    create index(:outbox_events, [:repository_id, :status, :inserted_at])
  end
end
