defmodule Vela.Repo.Migrations.UseMicrosecondEvidenceTimestamps do
  use Ecto.Migration

  def change do
    alter table(:evidence_events) do
      modify :inserted_at, :utc_datetime_usec, null: false
    end
  end
end
