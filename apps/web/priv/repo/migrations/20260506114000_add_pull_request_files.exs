defmodule Vela.Repo.Migrations.AddPullRequestFiles do
  use Ecto.Migration

  def change do
    create table(:pull_request_files, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :pull_request_id, references(:pull_requests, type: :binary_id, on_delete: :delete_all),
        null: false

      add :path, :text, null: false
      add :previous_path, :text
      add :status, :string, null: false
      add :additions, :integer, null: false, default: 0
      add :deletions, :integer, null: false, default: 0
      add :changes, :integer, null: false, default: 0
      add :patch, :text
      add :blob_url, :text
      add :raw_url, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pull_request_files, [:pull_request_id, :path])
    create index(:pull_request_files, [:pull_request_id, :status])
  end
end
