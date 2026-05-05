defmodule Vela.Repo.Migrations.AddCanCreatePrToAgentPolicies do
  use Ecto.Migration

  def change do
    alter table(:agent_policies) do
      add :can_create_pr, :boolean, null: false, default: false
    end
  end
end
