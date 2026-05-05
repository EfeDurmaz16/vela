defmodule Vela.RateLimit do
  @moduledoc """
  Lightweight in-node fixed-window limiter for org/user/token request gates.
  """

  @table :vela_rate_limits

  def check(key, opts) do
    table = table()
    limit = Keyword.fetch!(opts, :limit)
    window_ms = Keyword.fetch!(opts, :window_ms)
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table, key) do
      [{^key, count, reset_at}] when reset_at > now and count >= limit ->
        {:deny, reset_at - now}

      [{^key, count, reset_at}] when reset_at > now ->
        :ets.insert(table, {key, count + 1, reset_at})
        :allow

      _ ->
        :ets.insert(table, {key, 1, now + window_ms})
        :allow
    end
  end

  defp table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true, write_concurrency: true])

      tid ->
        tid
    end
  rescue
    ArgumentError -> @table
  end
end
