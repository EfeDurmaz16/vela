defmodule Vela.Agents.SignatureVerifier do
  @moduledoc "Signed agent identity verification boundary."

  @callback verify_agent_signature(map()) :: :ok | {:error, term()}
end
