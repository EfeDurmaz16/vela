defmodule Vela.AgentSignatureTest do
  use ExUnit.Case, async: true

  alias Vela.Agents.SignatureVerifier

  test "verifies Ed25519 agent signatures and rejects tampering" do
    {public_key, private_key} = :crypto.generate_key(:eddsa, :ed25519)
    message = Jason.encode!(%{action: "merge.simulate", nonce: "n-1"})
    signature = :crypto.sign(:eddsa, :none, message, [private_key, :ed25519])

    assert :ok =
             SignatureVerifier.verify_agent_signature(%{
               algorithm: "ed25519",
               public_key: Base.encode64(public_key),
               message: message,
               signature: Base.encode64(signature)
             })

    assert {:error, :invalid_signature} =
             SignatureVerifier.verify_agent_signature(%{
               algorithm: "ed25519",
               public_key: Base.encode64(public_key),
               message: message <> "!",
               signature: Base.encode64(signature)
             })
  end
end
