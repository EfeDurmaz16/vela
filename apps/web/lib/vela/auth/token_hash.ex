defmodule Vela.Auth.TokenHash do
  @moduledoc """
  HMAC-backed API token hashing.

  Raw API tokens are never persisted. The hash includes a purpose string so the
  same secret cannot be reused across unrelated HMAC domains without changing
  the resulting digest.
  """

  @purpose "vela:api-token:v1"
  @prefix "v1:hmac_sha256:"

  def hash_token(token, secret) when is_binary(token) and is_binary(secret) do
    with :ok <- require_present(token, :invalid_token),
         :ok <- require_present(secret, :invalid_secret) do
      {:ok, @prefix <> hmac_hex(secret, @purpose <> ":" <> token)}
    end
  end

  def hash_token(_, _), do: {:error, :invalid_token}

  def verify_token(token, stored_hash, secret)
      when is_binary(token) and is_binary(stored_hash) and is_binary(secret) do
    with {:ok, expected_hash} <- hash_token(token, secret),
         true <- secure_compare(expected_hash, stored_hash) do
      :ok
    else
      _ -> {:error, :invalid_token}
    end
  end

  def verify_token(_, _, _), do: {:error, :invalid_token}

  defp require_present(value, error) do
    if String.trim(value) == "", do: {:error, error}, else: :ok
  end

  defp hmac_hex(secret, payload) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  defp secure_compare(expected, actual)
       when byte_size(expected) == byte_size(actual) do
    Plug.Crypto.secure_compare(expected, actual)
  end

  defp secure_compare(expected, actual) when is_binary(expected) and is_binary(actual) do
    Plug.Crypto.secure_compare(expected, expected)
    false
  end
end
