defmodule Vela.WebhookVerifiersTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Vela.Webhooks
  alias Vela.Webhooks.Verifiers

  test "GitHub verifier accepts x-hub-signature-256" do
    body = ~s({"zen":"ship trusted software"})
    secret = "github_secret"

    conn =
      provider_conn(body)
      |> Plug.Conn.put_req_header("x-hub-signature-256", "sha256=" <> hex_hmac(secret, body))

    assert :ok == Verifiers.GitHub.verify(secret, conn, body, [])
  end

  test "Stripe verifier accepts stripe-signature v1 payloads" do
    body = ~s({"id":"evt_123"})
    secret = "stripe_secret"
    timestamp = "1777990000"
    signature = hex_hmac(secret, timestamp <> "." <> body)

    conn =
      provider_conn(body)
      |> Plug.Conn.put_req_header("stripe-signature", "t=#{timestamp},v1=#{signature}")

    assert :ok == Verifiers.Stripe.verify(secret, conn, body, [])
  end

  test "WorkOS verifier accepts workos-signature millisecond timestamps" do
    body = ~s({"event":"user.created"})
    secret = "workos_secret"
    timestamp = "1777990000000"
    signature = hex_hmac(secret, timestamp <> "." <> body)

    conn =
      provider_conn(body)
      |> Plug.Conn.put_req_header("workos-signature", "t=#{timestamp},v1=#{signature}")

    assert :ok == Verifiers.WorkOS.verify(secret, conn, body, [])
  end

  test "Svix verifier accepts whsec encoded signing secrets" do
    body = ~s({"event":"user.created"})
    raw_secret = "svix signing key"
    secret = "whsec_" <> Base.encode64(raw_secret)
    message_id = "msg_123"
    timestamp = "1777990000"

    signature =
      Base.encode64(:crypto.mac(:hmac, :sha256, raw_secret, "#{message_id}.#{timestamp}.#{body}"))

    conn =
      provider_conn(body)
      |> Plug.Conn.put_req_header("svix-id", message_id)
      |> Plug.Conn.put_req_header("svix-timestamp", timestamp)
      |> Plug.Conn.put_req_header("svix-signature", "v1,#{signature}")

    assert :ok == Verifiers.Svix.verify(secret, conn, body, [])
  end

  test "Generic verifier accepts Vela fallback signatures" do
    body = ~s({"event":"deployment.ready"})
    secret = "generic_secret"
    timestamp = "1777990000"
    signature = Webhooks.sign(secret, timestamp, body)

    conn =
      provider_conn(body)
      |> Plug.Conn.put_req_header("x-vela-timestamp", timestamp)
      |> Plug.Conn.put_req_header("x-vela-signature", signature)

    assert :ok == Verifiers.Generic.verify(secret, conn, body, [])
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
