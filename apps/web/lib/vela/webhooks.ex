defmodule Vela.Webhooks do
  @moduledoc """
  Signed webhook helpers with provider-specific header support.
  """

  alias Vela.Webhooks.Signatures
  alias Vela.Webhooks.Verifiers

  @verifiers %{
    "github" => Verifiers.GitHub,
    "stripe" => Verifiers.Stripe,
    "workos" => Verifiers.WorkOS,
    "svix" => Verifiers.Svix
  }

  def sign(secret, timestamp, body) when is_binary(secret) and is_binary(body) do
    Signatures.sign(secret, timestamp, body)
  end

  def verify_provider_request(provider, conn) do
    config = Application.get_env(:vela, :webhooks, [])
    secret = provider_secret(config, provider)
    require_signatures? = Keyword.get(config, :require_signatures?, false)
    body = conn.private[:raw_body] || ""

    cond do
      is_binary(secret) and secret != "" ->
        provider
        |> normalize_provider()
        |> verify_provider_signature(secret, conn, body, config)

      require_signatures? ->
        {:error, :missing_webhook_secret}

      true ->
        :ok
    end
  end

  def verify_signature(secret, timestamp, body, signature) when is_binary(signature) do
    Signatures.verify_signature(secret, timestamp, body, signature)
  end

  def verify_signature(_, _, _, _), do: {:error, :invalid_signature}

  defp provider_secret(config, provider) do
    provider = to_string(provider)

    config
    |> Keyword.get(:secrets, %{})
    |> Map.get(provider)
    |> case do
      value when is_binary(value) and value != "" -> value
      _ -> Keyword.get(config, :default_secret)
    end
  end

  defp normalize_provider(provider) do
    provider
    |> to_string()
    |> String.downcase()
  end

  defp verify_provider_signature(provider, secret, conn, body, config) do
    provider
    |> verifier()
    |> apply(:verify, [secret, conn, body, config])
  end

  defp verifier(provider), do: Map.get(@verifiers, provider, Verifiers.Generic)
end
