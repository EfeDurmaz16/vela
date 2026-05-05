defmodule Vela.Webhooks do
  @moduledoc """
  Signed webhook helpers with provider-specific header support.
  """

  @signature_headers ~w(x-vela-signature x-webhook-signature)
  @timestamp_headers ~w(x-vela-timestamp x-webhook-timestamp)
  @github_signature_header "x-hub-signature-256"
  @stripe_signature_header "stripe-signature"
  @workos_signature_header "workos-signature"
  @svix_signature_header "svix-signature"
  @svix_id_header "svix-id"
  @svix_timestamp_header "svix-timestamp"

  def sign(secret, timestamp, body) when is_binary(secret) and is_binary(body) do
    "v1=" <>
      (:crypto.mac(:hmac, :sha256, secret, timestamp <> "." <> body)
       |> Base.encode16(case: :lower))
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
        |> verify_provider_signature(secret, conn, body)

      require_signatures? ->
        {:error, :missing_webhook_secret}

      true ->
        :ok
    end
  end

  def verify_signature(secret, timestamp, body, signature) when is_binary(signature) do
    expected = sign(secret, timestamp, body)

    if secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  def verify_signature(_, _, _, _), do: {:error, :invalid_signature}

  defp verify_provider_signature("github", secret, conn, body) do
    case first_header(conn, [@github_signature_header]) do
      "sha256=" <> signature -> verify_hex_hmac(secret, body, signature)
      _ -> verify_generic_signature(secret, conn, body)
    end
  end

  defp verify_provider_signature("stripe", secret, conn, body) do
    with signature_header when is_binary(signature_header) <-
           first_header(conn, [@stripe_signature_header]),
         {:ok, timestamp, signatures} <- parse_timestamp_signature_header(signature_header),
         [_ | _] <- signatures do
      signed_payload = timestamp <> "." <> body
      expected = hex_hmac(secret, signed_payload)

      if Enum.any?(signatures, &secure_compare(expected, &1)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      _ -> verify_generic_signature(secret, conn, body)
    end
  end

  defp verify_provider_signature("workos", secret, conn, body) do
    with signature_header when is_binary(signature_header) <-
           first_header(conn, [@workos_signature_header]),
         {:ok, timestamp, signatures} <- parse_timestamp_signature_header(signature_header),
         [_ | _] <- signatures do
      signed_payload = timestamp <> "." <> body
      expected = hex_hmac(secret, signed_payload)

      if Enum.any?(signatures, &secure_compare(expected, &1)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      _ -> verify_svix_signature(secret, conn, body)
    end
  end

  defp verify_provider_signature("svix", secret, conn, body) do
    verify_svix_signature(secret, conn, body)
  end

  defp verify_provider_signature(_, secret, conn, body) do
    verify_generic_signature(secret, conn, body)
  end

  defp verify_svix_signature(secret, conn, body) do
    with message_id when is_binary(message_id) <- first_header(conn, [@svix_id_header]),
         timestamp when is_binary(timestamp) <- first_header(conn, [@svix_timestamp_header]),
         signature_header when is_binary(signature_header) <-
           first_header(conn, [@svix_signature_header]),
         {:ok, signing_secret} <- svix_signing_secret(secret),
         [_ | _] = signatures <- parse_svix_signature_header(signature_header) do
      signed_payload = message_id <> "." <> timestamp <> "." <> body
      expected = Base.encode64(:crypto.mac(:hmac, :sha256, signing_secret, signed_payload))

      if Enum.any?(signatures, &secure_compare(expected, &1)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      _ -> verify_generic_signature(secret, conn, body)
    end
  end

  defp verify_generic_signature(secret, conn, body) do
    verify_signature(
      secret,
      first_header(conn, @timestamp_headers),
      body,
      first_header(conn, @signature_headers)
    )
  end

  defp verify_hex_hmac(secret, signed_payload, signature) do
    expected = hex_hmac(secret, signed_payload)

    if secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp parse_timestamp_signature_header(header) do
    parts =
      header
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn part -> String.split(part, "=", parts: 2) end)

    timestamp =
      Enum.find_value(parts, fn
        ["t", timestamp] -> timestamp
        _ -> nil
      end)

    signatures =
      parts
      |> Enum.flat_map(fn
        ["v1", signature] -> [signature]
        _ -> []
      end)

    if is_binary(timestamp) do
      {:ok, timestamp, signatures}
    else
      :error
    end
  end

  defp parse_svix_signature_header(header) do
    header
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(fn signature ->
      case String.split(signature, ",", parts: 2) do
        ["v1", value] -> [value]
        _ -> []
      end
    end)
  end

  defp svix_signing_secret("whsec_" <> encoded_secret) do
    Base.decode64(encoded_secret)
  end

  defp svix_signing_secret(secret) when is_binary(secret) do
    {:ok, secret}
  end

  defp hex_hmac(secret, signed_payload) do
    :crypto.mac(:hmac, :sha256, secret, signed_payload)
    |> Base.encode16(case: :lower)
  end

  defp secure_compare(expected, actual)
       when is_binary(expected) and is_binary(actual) and byte_size(expected) == byte_size(actual) do
    Plug.Crypto.secure_compare(expected, actual)
  end

  defp secure_compare(expected, actual) when is_binary(expected) and is_binary(actual) do
    Plug.Crypto.secure_compare(expected, expected)
    false
  end

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

  defp first_header(conn, names) do
    names
    |> Enum.find_value(fn name -> Plug.Conn.get_req_header(conn, name) |> List.first() end)
  end
end
