defmodule Vela.Webhooks.Verifiers.Svix do
  @moduledoc "Svix-style webhook signature verifier."

  alias Vela.Webhooks.Signatures

  @signature_header "svix-signature"
  @id_header "svix-id"
  @timestamp_header "svix-timestamp"

  def verify(secret, conn, body, config) do
    with message_id when is_binary(message_id) <- Signatures.first_header(conn, [@id_header]),
         timestamp when is_binary(timestamp) <- Signatures.first_header(conn, [@timestamp_header]),
         signature_header when is_binary(signature_header) <-
           Signatures.first_header(conn, [@signature_header]),
         {:ok, signing_secret} <- Signatures.svix_signing_secret(secret),
         :ok <- Signatures.verify_timestamp(timestamp, config, :seconds),
         [_ | _] = signatures <- Signatures.parse_svix_signature_header(signature_header) do
      signed_payload = message_id <> "." <> timestamp <> "." <> body
      expected = Base.encode64(:crypto.mac(:hmac, :sha256, signing_secret, signed_payload))

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
