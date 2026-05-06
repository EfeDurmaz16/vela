defmodule Vela.Webhooks.Verifiers.Generic do
  @moduledoc "Generic Vela HMAC webhook signature verifier."

  alias Vela.Webhooks.Signatures

  def verify(secret, conn, body, config) do
    Signatures.verify_generic_signature(secret, conn, body, config)
  end
end
