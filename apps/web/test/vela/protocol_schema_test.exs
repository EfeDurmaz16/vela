defmodule Vela.ProtocolSchemaTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../../..", __DIR__)
  @events_schema Path.join(@repo_root, "packages/protocol/events.schema.json")
  @webhook_schema Path.join(@repo_root, "packages/protocol/webhook-events.schema.json")
  @webhook_examples_dir Path.join(@repo_root, "packages/protocol/examples/webhooks")

  test "evidence event schema defines explicit envelope versions" do
    schema = load_schema(@events_schema)

    assert schema["title"] == "Vela Evidence Event"
    assert schema["additionalProperties"] == false
    assert "schemaVersion" in schema["required"]
    assert "envelopeVersion" in schema["required"]

    assert get_in(schema, ["properties", "schemaVersion", "const"]) == "vela.evidence.v1"
    assert get_in(schema, ["properties", "envelopeVersion", "const"]) == 1
  end

  test "sample evidence envelope satisfies the protocol schema contract" do
    schema = load_schema(@events_schema)

    envelope = %{
      "schemaVersion" => "vela.evidence.v1",
      "envelopeVersion" => 1,
      "id" => "evt_123",
      "org_id" => "org_123",
      "repo_id" => "repo_123",
      "actor_id" => "actor_123",
      "event_type" => "merge.queued",
      "resource_type" => "merge_candidate",
      "resource_id" => "mc_123",
      "payload" => %{"merge_candidate_id" => "mc_123"},
      "payload_hash" => "sha256:payload",
      "prev_event_hash" => nil,
      "event_hash" => "sha256:event",
      "signature" => nil,
      "created_at" => "2026-05-06T11:00:00Z"
    }

    assert_schema_match!(schema, envelope)
  end

  test "schema rejects unknown envelope versions and undeclared fields" do
    schema = load_schema(@events_schema)

    bad_version = %{
      "schemaVersion" => "vela.evidence.v2",
      "envelopeVersion" => 1,
      "id" => "evt_123",
      "org_id" => "org_123",
      "actor_id" => "actor_123",
      "event_type" => "merge.queued",
      "resource_type" => "merge_candidate",
      "payload_hash" => "sha256:payload",
      "event_hash" => "sha256:event",
      "created_at" => "2026-05-06T11:00:00Z"
    }

    assert {:error, {:const, "schemaVersion", "vela.evidence.v1", "vela.evidence.v2"}} =
             schema_match(schema, bad_version)

    bad_envelope_version =
      bad_version
      |> Map.put("schemaVersion", "vela.evidence.v1")
      |> Map.put("envelopeVersion", 2)

    assert {:error, {:const, "envelopeVersion", 1, 2}} =
             schema_match(schema, bad_envelope_version)

    extra_field =
      Map.put(bad_version, "schemaVersion", "vela.evidence.v1") |> Map.put("extra", true)

    assert {:error, {:additional_properties, ["extra"]}} = schema_match(schema, extra_field)
  end

  test "webhook schema defines explicit versioned delivery envelope" do
    schema = load_schema(@webhook_schema)

    assert schema["title"] == "Vela Webhook Event"
    assert schema["additionalProperties"] == false
    assert "schemaVersion" in schema["required"]
    assert get_in(schema, ["properties", "schemaVersion", "const"]) == "vela.webhook.v1"
  end

  test "webhook examples satisfy the protocol schema contract" do
    schema = load_schema(@webhook_schema)

    examples =
      @webhook_examples_dir
      |> Path.join("*.json")
      |> Path.wildcard()
      |> Enum.sort()

    assert length(examples) == 4

    for path <- examples do
      event = load_schema(path)

      assert_schema_match!(schema, event)
      assert Path.basename(path, ".json") == event["type"]
      assert is_map(event["data"])
      assert map_size(event["data"]) > 0
    end
  end

  test "webhook schema rejects unknown schema versions and undeclared fields" do
    schema = load_schema(@webhook_schema)

    bad_version = %{
      "schemaVersion" => "vela.webhook.v2",
      "id" => "evt_123",
      "type" => "merge.queued",
      "created_at" => "2026-05-06T11:00:00Z",
      "data" => %{}
    }

    assert {:error, {:const, "schemaVersion", "vela.webhook.v1", "vela.webhook.v2"}} =
             schema_match(schema, bad_version)

    extra_field =
      bad_version
      |> Map.put("schemaVersion", "vela.webhook.v1")
      |> Map.put("delivery_attempt", 1)

    assert {:error, {:additional_properties, ["delivery_attempt"]}} =
             schema_match(schema, extra_field)
  end

  defp load_schema(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  defp assert_schema_match!(schema, value), do: assert(:ok == schema_match(schema, value))

  defp schema_match(%{"required" => required, "properties" => properties} = schema, value) do
    with :ok <- require_fields(required, value),
         :ok <- reject_additional(schema, value) do
      Enum.reduce_while(properties, :ok, fn {field, property}, :ok ->
        case validate_property(field, property, Map.get(value, field)) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp require_fields(required, value) do
    case Enum.reject(required, &Map.has_key?(value, &1)) do
      [] -> :ok
      missing -> {:error, {:missing_required, missing}}
    end
  end

  defp reject_additional(%{"additionalProperties" => false, "properties" => properties}, value) do
    allowed = Map.keys(properties) |> MapSet.new()

    case value |> Map.keys() |> Enum.reject(&MapSet.member?(allowed, &1)) do
      [] -> :ok
      extra -> {:error, {:additional_properties, extra}}
    end
  end

  defp reject_additional(_schema, _value), do: :ok

  defp validate_property(field, %{"const" => expected}, actual) do
    if actual == expected, do: :ok, else: {:error, {:const, field, expected, actual}}
  end

  defp validate_property(_field, %{"type" => "string"}, value) when is_binary(value), do: :ok
  defp validate_property(_field, %{"type" => "integer"}, value) when is_integer(value), do: :ok
  defp validate_property(_field, %{"type" => "object"}, value) when is_map(value), do: :ok

  defp validate_property(_field, %{"type" => allowed}, value) when is_list(allowed) do
    if Enum.any?(allowed, &type_match?(&1, value)),
      do: :ok,
      else: {:error, {:type, value, allowed}}
  end

  defp validate_property(_field, _property, _value), do: :ok

  defp type_match?("string", value), do: is_binary(value)
  defp type_match?("integer", value), do: is_integer(value)
  defp type_match?("object", value), do: is_map(value)
  defp type_match?("null", value), do: is_nil(value)
  defp type_match?(_type, _value), do: false
end
