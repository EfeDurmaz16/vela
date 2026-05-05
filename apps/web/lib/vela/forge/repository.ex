defmodule Vela.Forge.Repository do
  use Vela.Schema

  @visibilities ~w(private internal public)
  @risk_levels ~w(low medium high critical)
  @health_statuses ~w(healthy degraded failing unknown)
  @providers ~w(github)
  @import_statuses ~w(local pending imported failed)

  schema "repositories" do
    field :name, :string
    field :slug, :string
    field :visibility, :string, default: "private"
    field :default_branch, :string, default: "main"
    field :description, :string
    field :provider, :string
    field :external_id, :string
    field :full_name, :string
    field :html_url, :string
    field :import_status, :string, default: "local"
    field :imported_at, :utc_datetime
    field :last_import_error, :string
    field :repo_cell_id, :string
    field :health_status, :string, default: "healthy"
    field :risk_level, :string, default: "low"

    belongs_to :organization, Vela.Accounts.Organization
    has_many :branches, Vela.Forge.Branch
    has_many :changes, Vela.Forge.Change
    has_many :pull_requests, Vela.Forge.PullRequest
    has_many :repository_trust_signals, Vela.Forge.RepositoryTrustSignal

    timestamps(type: :utc_datetime)
  end

  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [
      :organization_id,
      :name,
      :slug,
      :visibility,
      :default_branch,
      :description,
      :provider,
      :external_id,
      :full_name,
      :html_url,
      :import_status,
      :imported_at,
      :last_import_error,
      :repo_cell_id,
      :health_status,
      :risk_level
    ])
    |> validate_required([
      :organization_id,
      :name,
      :slug,
      :visibility,
      :default_branch,
      :health_status,
      :risk_level
    ])
    |> Vela.Validation.validate_inclusion(:visibility, @visibilities)
    |> Vela.Validation.validate_inclusion(:risk_level, @risk_levels)
    |> Vela.Validation.validate_inclusion(:health_status, @health_statuses)
    |> validate_provider()
    |> Vela.Validation.validate_inclusion(:import_status, @import_statuses)
    |> unique_constraint([:organization_id, :slug])
  end

  defp validate_provider(changeset) do
    case get_field(changeset, :provider) do
      nil -> changeset
      _ -> Vela.Validation.validate_inclusion(changeset, :provider, @providers)
    end
  end
end
