defmodule Vela.Crypto do
  @moduledoc """
  Minimal encryption helpers for integration token ciphertext fields.
  """

  @aad "vela:integration-token:v1"

  def encrypt_token(plaintext, secret) when is_binary(plaintext) and byte_size(secret) == 32 do
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, secret, iv, plaintext, @aad, true)

    Enum.join(
      [
        "v1",
        Base.url_encode64(iv, padding: false),
        Base.url_encode64(ciphertext, padding: false),
        Base.url_encode64(tag, padding: false)
      ],
      "."
    )
  end

  def decrypt_token("v1." <> rest, secret) when byte_size(secret) == 32 do
    with [iv64, ciphertext64, tag64] <- String.split(rest, "."),
         {:ok, iv} <- Base.url_decode64(iv64, padding: false),
         {:ok, ciphertext} <- Base.url_decode64(ciphertext64, padding: false),
         {:ok, tag} <- Base.url_decode64(tag64, padding: false),
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, secret, iv, ciphertext, @aad, tag, false) do
      {:ok, plaintext}
    else
      _ -> {:error, :decrypt_failed}
    end
  end

  def decrypt_token(_, _), do: {:error, :decrypt_failed}
end
