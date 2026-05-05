defmodule Vela.Integrations.Integration do
  use Vela.Schema

  @providers ~w(vercel supabase neon workos sentry axiom trigger_dev inngest upstash modal stripe cloudflare github)
  @statuses ~w(active disabled error pending)

  schema "integrations" do
    field :provider, :string
    field :name, :string
    field :status, :string, default: "active"
    field :config, :map, default: %{}
    field :token_ciphertext, :string
    field :external_ref, :string

    belongs_to :organization, Vela.Accounts.Organization
    has_many :service_connections, Vela.Integrations.ServiceConnection

    timestamps(type: :utc_datetime)
  end

  def providers, do: @providers

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :organization_id,
      :provider,
      :name,
      :status,
      :config,
      :token_ciphertext,
      :external_ref
    ])
    |> validate_required([:organization_id, :provider, :name, :status])
    |> Vela.Validation.validate_inclusion(:provider, @providers)
    |> Vela.Validation.validate_inclusion(:status, @statuses)
    |> unique_constraint([:organization_id, :provider, :name])
  end
end
