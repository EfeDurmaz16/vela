defmodule Vela.Agents.SignatureVerifier do
  @moduledoc "Signed agent identity verification boundary."

  @callback verify_agent_signature(map()) :: :ok | {:error, term()}

  def verify_agent_signature(%{
        algorithm: "ed25519",
        public_key: public_key,
        message: message,
        signature: signature
      })
      when is_binary(public_key) and is_binary(message) and is_binary(signature) do
    with {:ok, decoded_public_key} <- Base.decode64(public_key),
         {:ok, decoded_signature} <- Base.decode64(signature),
         true <-
           :crypto.verify(:eddsa, :none, message, decoded_signature, [
             decoded_public_key,
             :ed25519
           ]) do
      :ok
    else
      false -> {:error, :invalid_signature}
      :error -> {:error, :invalid_encoding}
    end
  end

  def verify_agent_signature(_), do: {:error, :unsupported_signature}
end
