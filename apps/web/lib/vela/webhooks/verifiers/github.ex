defmodule Vela.Webhooks.Verifiers.GitHub do
  @moduledoc "GitHub webhook signature verifier."

  alias Vela.Webhooks.Signatures

  @signature_header "x-hub-signature-256"

  def verify(secret, conn, body, config) do
    case Signatures.first_header(conn, [@signature_header]) do
      "sha256=" <> signature -> Signatures.verify_hex_hmac(secret, body, signature)
      _ -> Signatures.verify_generic_signature(secret, conn, body, config)
    end
  end
end
