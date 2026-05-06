defmodule Vela.Repo.Migrations.AddUniquePullRequestProviderIds do
  use Ecto.Migration

  def change do
    drop_if_exists index(:pull_requests, [:repository_id, :provider, :external_number],
                     name: :pull_requests_repository_id_provider_external_number_index
                   )

    create unique_index(:pull_requests, [:repository_id, :provider, :external_number])
    create unique_index(:pull_requests, [:repository_id, :provider, :external_id])
  end
end
