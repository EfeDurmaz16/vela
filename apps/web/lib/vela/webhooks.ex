defmodule Vela.Webhooks do
  @moduledoc """
  Signed webhook helpers. Providers can wrap this with provider-specific headers.
  """

  @signature_headers ~w(x-vela-signature x-webhook-signature)
  @timestamp_headers ~w(x-vela-timestamp x-webhook-timestamp)

  def sign(secret, timestamp, body) when is_binary(secret) and is_binary(body) do
    "v1=" <>
      (:crypto.mac(:hmac, :sha256, secret, timestamp <> "." <> body)
       |> Base.encode16(case: :lower))
  end

  def verify_provider_request(provider, conn) do
    config = Application.get_env(:vela, :webhooks, [])
    secret = provider_secret(config, provider)
    require_signatures? = Keyword.get(config, :require_signatures?, false)

    cond do
      is_binary(secret) and secret != "" ->
        verify_signature(
          secret,
          first_header(conn, @timestamp_headers),
          conn.private[:raw_body] || "",
          first_header(conn, @signature_headers)
        )

      require_signatures? ->
        {:error, :missing_webhook_secret}

      true ->
        :ok
    end
  end

  def verify_signature(secret, timestamp, body, signature) when is_binary(signature) do
    expected = sign(secret, timestamp, body)

    if Plug.Crypto.secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
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

  defp first_header(conn, names) do
    names
    |> Enum.find_value(fn name -> Plug.Conn.get_req_header(conn, name) |> List.first() end)
  end
end
