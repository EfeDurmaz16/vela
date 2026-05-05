defmodule Vela.WebhooksTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  import Plug.Test

  alias Vela.Webhooks

  setup do
    previous = Application.get_env(:vela, :webhooks)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vela, :webhooks, previous),
        else: Application.delete_env(:vela, :webhooks)
    end)
  end

  test "verifies signed webhook payloads with constant-time HMAC comparison" do
    secret = "whsec_test"
    body = ~s({"event":"repo.push"})
    timestamp = "1777990000"
    signature = Webhooks.sign(secret, timestamp, body)

    assert :ok == Webhooks.verify_signature(secret, timestamp, body, signature)

    assert {:error, :invalid_signature} =
             Webhooks.verify_signature(secret, timestamp, body, "bad")
  end

  test "verifies GitHub x-hub-signature-256 signatures" do
    body = ~s({"zen":"Keep it logically awesome."})
    secret = "github_secret"

    conn =
      provider_conn(body)
      |> put_req_header("x-hub-signature-256", "sha256=" <> hex_hmac(secret, body))

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"github" => secret}
    )

    assert :ok == Webhooks.verify_provider_request("github", conn)

    invalid_conn =
      provider_conn(body)
      |> put_req_header("x-hub-signature-256", "sha256=" <> String.duplicate("0", 64))

    assert {:error, :invalid_signature} ==
             Webhooks.verify_provider_request("github", invalid_conn)
  end

  test "verifies Stripe stripe-signature v1 signatures" do
    body = ~s({"id":"evt_123","type":"checkout.session.completed"})
    secret = "whsec_stripe"
    timestamp = "1777990000"

    signature = hex_hmac(secret, timestamp <> "." <> body)

    conn =
      provider_conn(body)
      |> put_req_header("stripe-signature", "t=#{timestamp},v1=#{signature},v0=legacy")

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"stripe" => secret}
    )

    assert :ok == Webhooks.verify_provider_request(:stripe, conn)

    invalid_conn =
      provider_conn(body)
      |> put_req_header("stripe-signature", "t=#{timestamp},v1=#{String.duplicate("f", 64)}")

    assert {:error, :invalid_signature} ==
             Webhooks.verify_provider_request("stripe", invalid_conn)
  end

  test "rejects Stripe signatures outside the configured replay window" do
    body = ~s({"id":"evt_old","type":"checkout.session.completed"})
    secret = "whsec_stripe"
    timestamp = "1777990000"
    signature = hex_hmac(secret, timestamp <> "." <> body)

    conn =
      provider_conn(body)
      |> put_req_header("stripe-signature", "t=#{timestamp},v1=#{signature}")

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      tolerance_seconds: 300,
      now: fn -> 1_778_000_000 end,
      secrets: %{"stripe" => secret}
    )

    assert {:error, :stale_timestamp} ==
             Webhooks.verify_provider_request("stripe", conn)
  end

  test "verifies WorkOS workos-signature headers" do
    body = ~s({"event":"user.created"})
    secret = "workos_secret"
    timestamp = "1777990000000"
    signature = hex_hmac(secret, timestamp <> "." <> body)

    conn =
      provider_conn(body)
      |> put_req_header("workos-signature", "t=#{timestamp},v1=#{signature}")

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"workos" => secret}
    )

    assert :ok == Webhooks.verify_provider_request("workos", conn)

    invalid_conn =
      provider_conn(body)
      |> put_req_header("workos-signature", "t=#{timestamp},v1=#{String.duplicate("f", 64)}")

    assert {:error, :invalid_signature} ==
             Webhooks.verify_provider_request("workos", invalid_conn)
  end

  test "verifies Svix-style webhook signatures" do
    body = ~s({"event":"user.created"})
    raw_secret = "workos svix signing key"
    secret = "whsec_" <> Base.encode64(raw_secret)
    message_id = "msg_123"
    timestamp = "1777990000"

    signature =
      Base.encode64(:crypto.mac(:hmac, :sha256, raw_secret, "#{message_id}.#{timestamp}.#{body}"))

    conn =
      provider_conn(body)
      |> put_req_header("svix-id", message_id)
      |> put_req_header("svix-timestamp", timestamp)
      |> put_req_header("svix-signature", "v1,#{signature}")

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"svix" => secret}
    )

    assert :ok == Webhooks.verify_provider_request("svix", conn)

    invalid_conn =
      provider_conn(body)
      |> put_req_header("svix-id", message_id)
      |> put_req_header("svix-timestamp", timestamp)
      |> put_req_header("svix-signature", "v1,#{Base.encode64("bad")}")

    assert {:error, :invalid_signature} ==
             Webhooks.verify_provider_request("svix", invalid_conn)
  end

  test "requires a configured secret for provider-specific verifiers when signatures are required" do
    body = ~s({"id":"evt_123"})

    conn =
      provider_conn(body)
      |> put_req_header("x-hub-signature-256", "sha256=" <> hex_hmac("github_secret", body))

    Application.put_env(:vela, :webhooks, require_signatures?: true, secrets: %{})

    assert {:error, :missing_webhook_secret} ==
             Webhooks.verify_provider_request("github", conn)
  end

  test "preserves generic x-vela fallback for providers without a specific verifier" do
    body = ~s({"event":"deployment.ready"})
    timestamp = "1777990000"
    secret = "generic_secret"
    signature = Webhooks.sign(secret, timestamp, body)

    conn =
      provider_conn(body)
      |> put_req_header("x-vela-timestamp", timestamp)
      |> put_req_header("x-vela-signature", signature)

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      secrets: %{"vercel" => secret}
    )

    assert :ok == Webhooks.verify_provider_request("vercel", conn)
  end

  test "rejects generic signatures outside the configured replay window" do
    body = ~s({"event":"deployment.ready"})
    timestamp = "1777990000"
    secret = "generic_secret"
    signature = Webhooks.sign(secret, timestamp, body)

    conn =
      provider_conn(body)
      |> put_req_header("x-vela-timestamp", timestamp)
      |> put_req_header("x-vela-signature", signature)

    Application.put_env(:vela, :webhooks,
      require_signatures?: true,
      tolerance_seconds: 300,
      now: fn -> 1_778_000_000 end,
      secrets: %{"vercel" => secret}
    )

    assert {:error, :stale_timestamp} ==
             Webhooks.verify_provider_request("vercel", conn)
  end

  defp provider_conn(body) do
    :post
    |> conn("/api/v1/webhooks/provider", body)
    |> Plug.Conn.put_private(:raw_body, body)
  end

  defp hex_hmac(secret, signed_payload) do
    :crypto.mac(:hmac, :sha256, secret, signed_payload)
    |> Base.encode16(case: :lower)
  end
end
