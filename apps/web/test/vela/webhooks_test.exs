defmodule Vela.WebhooksTest do
  use ExUnit.Case, async: true

  alias Vela.Webhooks

  test "verifies signed webhook payloads with constant-time HMAC comparison" do
    secret = "whsec_test"
    body = ~s({"event":"repo.push"})
    timestamp = "1777990000"
    signature = Webhooks.sign(secret, timestamp, body)

    assert :ok == Webhooks.verify_signature(secret, timestamp, body, signature)

    assert {:error, :invalid_signature} =
             Webhooks.verify_signature(secret, timestamp, body, "bad")
  end
end
