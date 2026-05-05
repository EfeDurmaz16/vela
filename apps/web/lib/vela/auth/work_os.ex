defmodule Vela.Auth.WorkOS do
  @moduledoc "WorkOS SSO boundary for human authentication."

  @callback authorization_url(map()) :: {:ok, URI.t()} | {:error, term()}
  @callback exchange_code(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_session(map()) :: {:ok, map()} | {:error, term()}
end
