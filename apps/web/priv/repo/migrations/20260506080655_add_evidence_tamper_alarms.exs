defmodule Vela.Repo.Migrations.AddEvidenceTamperAlarms do
  use Ecto.Migration

  def change do
    create table(:evidence_tamper_alarms, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :nilify_all)

      add :evidence_event_id,
          references(:evidence_events, type: :binary_id, on_delete: :nilify_all)

      add :reason, :string, null: false
      add :event_hash, :string
      add :status, :string, null: false, default: "open"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:evidence_tamper_alarms, [:organization_id, :inserted_at])
    create index(:evidence_tamper_alarms, [:repository_id, :inserted_at])

    create unique_index(:evidence_tamper_alarms, [:organization_id, :event_hash, :reason])
  end
end
