defmodule Vela.Repo.Migrations.AddBranchProtectionRequirements do
  use Ecto.Migration

  def change do
    alter table(:branches) do
      add :required_approvals, :integer, null: false, default: 1
      add :required_checks, {:array, :string}, null: false, default: []
    end
  end
end
