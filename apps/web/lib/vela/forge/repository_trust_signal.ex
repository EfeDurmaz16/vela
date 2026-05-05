defmodule Vela.Forge.RepositoryTrustSignal do
  use Vela.Schema

  @confidences ~w(low medium high)

  schema "repository_trust_signals" do
    field :source, :string
    field :signal_type, :string
    field :score, :integer
    field :confidence, :string, default: "medium"
    field :payload, :map, default: %{}

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(signal, attrs) do
    signal
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :source,
      :signal_type,
      :score,
      :confidence,
      :payload
    ])
    |> validate_required([
      :organization_id,
      :repository_id,
      :source,
      :signal_type,
      :score,
      :confidence
    ])
    |> Vela.Validation.validate_score(:score)
    |> Vela.Validation.validate_inclusion(:confidence, @confidences)
  end
end
