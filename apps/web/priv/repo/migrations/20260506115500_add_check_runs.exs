defmodule Vela.Repo.Migrations.AddCheckRuns do
  use Ecto.Migration

  def change do
    create table(:check_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :repository_id, references(:repositories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :delete_all)
      add :provider, :string, null: false
      add :external_id, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :conclusion, :string
      add :details_url, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:check_runs, [:provider, :external_id])
    create index(:check_runs, [:repository_id, :status])
    create index(:check_runs, [:pull_request_id])
  end
end
