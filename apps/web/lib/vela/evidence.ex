defmodule Vela.Evidence do
  @moduledoc """
  Append-only, hash-chained evidence events.
  """

  import Ecto.Query

  alias Vela.Evidence.EvidenceEvent
  alias Vela.Repo

  def append_event(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    payload = Map.get(attrs, :payload, %{})
    payload_hash = hash(payload)
    prev_event_hash = latest_event_hash(attrs.organization_id)

    event_body = %{
      organization_id: attrs.organization_id,
      repository_id: Map.get(attrs, :repository_id),
      actor_id: attrs.actor_id,
      event_type: attrs.event_type,
      resource_type: attrs.resource_type,
      resource_id: Map.get(attrs, :resource_id),
      payload_hash: payload_hash,
      prev_event_hash: prev_event_hash,
      inserted_at: DateTime.to_iso8601(now)
    }

    %EvidenceEvent{inserted_at: now}
    |> EvidenceEvent.changeset(
      attrs
      |> Map.put(:payload, payload)
      |> Map.put(:payload_hash, payload_hash)
      |> Map.put(:prev_event_hash, prev_event_hash)
      |> Map.put(:event_hash, hash(event_body))
      |> Map.put(:inserted_at, now)
    )
    |> Repo.insert()
  end

  def list_recent_events(limit \\ 25) do
    EvidenceEvent
    |> preload([:organization, :repository, :actor])
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_repository_events(repository_id, limit \\ 10) do
    EvidenceEvent
    |> where([e], e.repository_id == ^repository_id)
    |> preload([:actor, :repository])
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def hash(value),
    do: "sha256:" <> (:crypto.hash(:sha256, canonical_json(value)) |> Base.encode16(case: :lower))

  def canonical_json(value), do: value |> normalize() |> Jason.encode!()

  defp latest_event_hash(organization_id) do
    EvidenceEvent
    |> where([e], e.organization_id == ^organization_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(1)
    |> select([e], e.event_hash)
    |> Repo.one()
  end

  defp normalize(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), normalize(value)} end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Map.new()
  end

  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize(value), do: value
end
