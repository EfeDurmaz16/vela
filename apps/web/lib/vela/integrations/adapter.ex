defmodule Vela.Integrations.Adapter do
  @moduledoc "Provider integration adapter behaviour."

  @callback provider() :: String.t()
  @callback normalize_event(map()) :: {:ok, map()} | {:error, term()}
end
