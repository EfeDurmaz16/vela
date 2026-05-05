defmodule Vela.Repo.Migrations.AddPullRequestProviderMetadata do
  use Ecto.Migration

  def change do
    alter table(:pull_requests) do
      add :provider, :string
      add :external_id, :string
      add :external_number, :integer
      add :html_url, :string
    end

    create index(:pull_requests, [:repository_id, :provider, :external_number])
  end
end
