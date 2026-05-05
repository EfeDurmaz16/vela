defmodule Vela.Integrations.ProviderAdapter do
  @moduledoc false

  defmacro __using__(provider: provider) do
    quote do
      @behaviour Vela.Integrations.Adapter

      @impl Vela.Integrations.Adapter
      def provider, do: unquote(provider)

      @impl Vela.Integrations.Adapter
      def normalize_event(payload) when is_map(payload) do
        {:ok,
         %{
           event_type: "integration.event_received",
           resource_type: "integration",
           external_event_id: payload["id"] || payload["event_id"],
           payload: %{
             "provider" => unquote(provider),
             "provider_event_type" => payload["type"] || payload["event"] || payload["action"],
             "raw" => payload
           }
         }}
      end
    end
  end
end
