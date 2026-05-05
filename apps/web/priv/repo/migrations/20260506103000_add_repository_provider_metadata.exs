defmodule Vela.Repo.Migrations.AddRepositoryProviderMetadata do
  use Ecto.Migration

  def change do
    alter table(:repositories) do
      add :provider, :string
      add :external_id, :string
      add :full_name, :string
      add :html_url, :string
      add :import_status, :string, null: false, default: "local"
      add :imported_at, :utc_datetime
      add :last_import_error, :text
    end

    create index(:repositories, [:organization_id, :provider, :external_id])
    create index(:repositories, [:organization_id, :import_status])
  end
end
