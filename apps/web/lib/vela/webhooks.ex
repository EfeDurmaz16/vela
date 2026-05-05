defmodule Vela.Webhooks do
  @moduledoc """
  Signed webhook helpers. Providers can wrap this with provider-specific headers.
  """

  def sign(secret, timestamp, body) when is_binary(secret) and is_binary(body) do
    "v1=" <>
      (:crypto.mac(:hmac, :sha256, secret, timestamp <> "." <> body)
       |> Base.encode16(case: :lower))
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
end
