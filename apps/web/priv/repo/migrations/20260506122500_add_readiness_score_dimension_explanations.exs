defmodule Vela.Repo.Migrations.AddReadinessScoreDimensionExplanations do
  use Ecto.Migration

  def change do
    alter table(:readiness_scores) do
      add :dimension_explanations, :map, default: %{}, null: false
    end
  end
end
