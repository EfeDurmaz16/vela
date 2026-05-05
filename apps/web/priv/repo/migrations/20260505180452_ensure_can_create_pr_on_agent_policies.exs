defmodule Vela.Repo.Migrations.EnsureCanCreatePrOnAgentPolicies do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE agent_policies ADD COLUMN IF NOT EXISTS can_create_pr boolean NOT NULL DEFAULT false"
  end

  def down do
    execute "ALTER TABLE agent_policies DROP COLUMN IF EXISTS can_create_pr"
  end
end
