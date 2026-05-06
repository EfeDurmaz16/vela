defmodule Vela.Webhooks.Verifiers.Stripe do
  @moduledoc "Stripe webhook signature verifier."

  alias Vela.Webhooks.Signatures

  @signature_header "stripe-signature"

  def verify(secret, conn, body, config) do
    with signature_header when is_binary(signature_header) <-
           Signatures.first_header(conn, [@signature_header]),
         {:ok, timestamp, signatures} <-
           Signatures.parse_timestamp_signature_header(signature_header),
         :ok <- Signatures.verify_timestamp(timestamp, config, :seconds),
         [_ | _] <- signatures do
      signed_payload = timestamp <> "." <> body
      expected = Signatures.hex_hmac(secret, signed_payload)

      if Enum.any?(signatures, &Signatures.secure_compare(expected, &1)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      {:error, :stale_timestamp} -> {:error, :stale_timestamp}
      _ -> Signatures.verify_generic_signature(secret, conn, body, config)
    end
  end
end
