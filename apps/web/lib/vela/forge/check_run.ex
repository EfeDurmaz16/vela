defmodule Vela.Forge.CheckRun do
  use Vela.Schema

  @statuses ~w(queued in_progress completed waiting requested pending)
  @conclusions ~w(success failure neutral cancelled skipped timed_out action_required startup_failure stale)
  @providers ~w(github)

  schema "check_runs" do
    field :provider, :string
    field :external_id, :string
    field :name, :string
    field :status, :string
    field :conclusion, :string
    field :details_url, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :repository, Vela.Forge.Repository
    belongs_to :pull_request, Vela.Forge.PullRequest

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def conclusions, do: @conclusions

  def changeset(check_run, attrs) do
    check_run
    |> cast(attrs, [
      :repository_id,
      :pull_request_id,
      :provider,
      :external_id,
      :name,
      :status,
      :conclusion,
      :details_url,
      :started_at,
      :completed_at
    ])
    |> validate_required([:repository_id, :provider, :external_id, :name, :status])
    |> Vela.Validation.validate_inclusion(:provider, @providers)
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> validate_conclusion()
    |> foreign_key_constraint(:repository_id)
    |> foreign_key_constraint(:pull_request_id)
    |> unique_constraint([:provider, :external_id])
  end

  defp validate_conclusion(changeset) do
    case get_field(changeset, :conclusion) do
      nil -> changeset
      _ -> Vela.Validation.validate_inclusion(changeset, :conclusion, @conclusions)
    end
  end
end
