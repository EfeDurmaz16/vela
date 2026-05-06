defmodule Vela.Webhooks.Signatures do
  @moduledoc """
  Shared webhook signature parsing and verification helpers.
  """

  @signature_headers ~w(x-vela-signature x-webhook-signature)
  @timestamp_headers ~w(x-vela-timestamp x-webhook-timestamp)

  def sign(secret, timestamp, body) when is_binary(secret) and is_binary(body) do
    "v1=" <>
      (:crypto.mac(:hmac, :sha256, secret, timestamp <> "." <> body)
       |> Base.encode16(case: :lower))
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

  def verify_generic_signature(secret, conn, body, config \\ []) do
    timestamp = first_header(conn, @timestamp_headers)

    with :ok <- verify_timestamp(timestamp, config, :seconds) do
      verify_signature(secret, timestamp, body, first_header(conn, @signature_headers))
    end
  end

  def verify_hex_hmac(secret, signed_payload, signature) do
    expected = hex_hmac(secret, signed_payload)

    if secure_compare(expected, signature) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  def parse_timestamp_signature_header(header) do
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

  def parse_svix_signature_header(header) do
    header
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(fn signature ->
      case String.split(signature, ",", parts: 2) do
        ["v1", value] -> [value]
        _ -> []
      end
    end)
  end

  def svix_signing_secret("whsec_" <> encoded_secret) do
    Base.decode64(encoded_secret)
  end

  def svix_signing_secret(secret) when is_binary(secret) do
    {:ok, secret}
  end

  def hex_hmac(secret, signed_payload) do
    :crypto.mac(:hmac, :sha256, secret, signed_payload)
    |> Base.encode16(case: :lower)
  end

  def verify_timestamp(timestamp, config, unit) do
    case Keyword.get(config, :tolerance_seconds) do
      tolerance when is_integer(tolerance) and tolerance > 0 ->
        with {timestamp, ""} <- Integer.parse(to_string(timestamp)),
             timestamp <- normalize_timestamp(timestamp, unit),
             true <- abs(now(config) - timestamp) <= tolerance do
          :ok
        else
          _ -> {:error, :stale_timestamp}
        end

      _ ->
        :ok
    end
  end

  def secure_compare(expected, actual)
      when is_binary(expected) and is_binary(actual) and byte_size(expected) == byte_size(actual) do
    Plug.Crypto.secure_compare(expected, actual)
  end

  def secure_compare(expected, actual) when is_binary(expected) and is_binary(actual) do
    Plug.Crypto.secure_compare(expected, expected)
    false
  end

  def first_header(conn, names) do
    names
    |> Enum.find_value(fn name -> Plug.Conn.get_req_header(conn, name) |> List.first() end)
  end

  defp normalize_timestamp(timestamp, :milliseconds), do: div(timestamp, 1_000)
  defp normalize_timestamp(timestamp, :seconds), do: timestamp

  defp now(config) do
    case Keyword.get(config, :now) do
      fun when is_function(fun, 0) -> fun.()
      _ -> System.system_time(:second)
    end
  end
end
