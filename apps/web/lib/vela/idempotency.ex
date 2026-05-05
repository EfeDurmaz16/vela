defmodule Vela.Idempotency do
  @moduledoc "Request idempotency helpers for mutation endpoints."

  alias Vela.Idempotency.IdempotencyKey
  alias Vela.Repo

  @ttl_seconds 24 * 60 * 60

  def run(conn, organization_id, actor_id, fun) when is_function(fun, 0) do
    case idempotency_key(conn) do
      nil ->
        {:ok, fun.()}

      key ->
        request_hash = request_hash(conn)

        case existing_record(organization_id, key) do
          %IdempotencyKey{
            request_hash: ^request_hash,
            response_status: status,
            response_body: body
          } ->
            {:replay, {status, body}}

          %IdempotencyKey{} ->
            {:conflict, :idempotency_key_reused}

          nil ->
            {status, body} = fun.()

            %IdempotencyKey{}
            |> IdempotencyKey.changeset(%{
              key: key,
              organization_id: organization_id,
              actor_id: actor_id,
              request_hash: request_hash,
              response_status: status,
              response_body: body,
              expires_at: expires_at()
            })
            |> Repo.insert!()

            {:ok, {status, body}}
        end
    end
  end

  defp idempotency_key(conn) do
    conn
    |> Plug.Conn.get_req_header("idempotency-key")
    |> List.first()
    |> case do
      key when is_binary(key) and byte_size(key) >= 8 -> key
      _ -> nil
    end
  end

  defp existing_record(organization_id, key) do
    case Repo.get_by(IdempotencyKey, organization_id: organization_id, key: key) do
      %IdempotencyKey{expires_at: expires_at} = record ->
        if DateTime.compare(expires_at, DateTime.utc_now(:second)) == :gt, do: record

      nil ->
        nil
    end
  end

  defp request_hash(conn) do
    payload = %{
      method: conn.method,
      path: conn.request_path,
      params: normalize(conn.params)
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(payload))
    |> Base.encode16(case: :lower)
  end

  defp normalize(map) when is_map(map) do
    map
    |> Map.new(fn {key, value} -> {to_string(key), normalize(value)} end)
    |> Enum.sort_by(fn {key, _value} -> key end)
  end

  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  defp normalize(value), do: value

  defp expires_at do
    DateTime.utc_now(:second)
    |> DateTime.add(@ttl_seconds, :second)
  end
end
