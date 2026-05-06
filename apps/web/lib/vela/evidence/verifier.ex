defmodule Vela.Evidence.Verifier do
  @moduledoc """
  Verifies hash-chained evidence streams.
  """

  import Ecto.Query

  alias Vela.Evidence
  alias Vela.Evidence.EvidenceEvent
  alias Vela.Repo

  def verify_chain(organization_id, repository_id \\ nil) do
    organization_id
    |> events_query(repository_id)
    |> Repo.all()
    |> verify_events(nil, 0)
  end

  defp events_query(organization_id, nil) do
    EvidenceEvent
    |> where([e], e.organization_id == ^organization_id and is_nil(e.repository_id))
    |> order_by([e], asc: e.inserted_at, asc: e.id)
  end

  defp events_query(organization_id, repository_id) do
    EvidenceEvent
    |> where([e], e.organization_id == ^organization_id and e.repository_id == ^repository_id)
    |> order_by([e], asc: e.inserted_at, asc: e.id)
  end

  defp verify_events([], previous_hash, count),
    do: {:ok, %{count: count, last_hash: previous_hash}}

  defp verify_events([event | rest], previous_hash, count) do
    with :ok <- verify_previous_hash(event, previous_hash),
         :ok <- verify_payload_hash(event),
         :ok <- verify_event_hash(event) do
      verify_events(rest, event.event_hash, count + 1)
    end
  end

  defp verify_previous_hash(%EvidenceEvent{} = event, expected_hash) do
    if event.prev_event_hash == expected_hash do
      :ok
    else
      invalid(event, :prev_event_hash_mismatch)
    end
  end

  defp verify_payload_hash(%EvidenceEvent{} = event) do
    expected_hash = Evidence.hash(event.payload || %{})

    if event.payload_hash == expected_hash do
      :ok
    else
      invalid(event, :payload_hash_mismatch)
    end
  end

  defp verify_event_hash(%EvidenceEvent{} = event) do
    expected_hash =
      Evidence.hash(%{
        organization_id: event.organization_id,
        repository_id: event.repository_id,
        actor_id: event.actor_id,
        event_type: event.event_type,
        resource_type: event.resource_type,
        resource_id: event.resource_id,
        payload_hash: event.payload_hash,
        prev_event_hash: event.prev_event_hash,
        inserted_at: DateTime.to_iso8601(event.inserted_at)
      })

    if event.event_hash == expected_hash do
      :ok
    else
      invalid(event, :event_hash_mismatch)
    end
  end

  defp invalid(%EvidenceEvent{} = event, reason) do
    {:error, %{reason: reason, event_id: event.id, event_hash: event.event_hash}}
  end
end
