defmodule Vela.SecurityFoundationTest do
  use ExUnit.Case, async: true

  alias Vela.{Crypto, RateLimit}

  test "integration token encryption round-trips without returning plaintext ciphertext" do
    secret = String.duplicate("a", 32)
    token = "vercel-secret-token"

    ciphertext = Crypto.encrypt_token(token, secret)

    refute ciphertext == token
    assert {:ok, ^token} = Crypto.decrypt_token(ciphertext, secret)
  end

  test "rate limit decisions fail closed after the configured limit" do
    key = {:test, self()}
    assert :allow = RateLimit.check(key, limit: 2, window_ms: 60_000)
    assert :allow = RateLimit.check(key, limit: 2, window_ms: 60_000)
    assert {:deny, _retry_after_ms} = RateLimit.check(key, limit: 2, window_ms: 60_000)
  end
end
