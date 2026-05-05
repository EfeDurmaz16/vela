defmodule Vela.Jobs.WorkerGuards do
  @moduledoc false

  def require_keys(args, keys) do
    case Enum.reject(keys, &Map.has_key?(args, &1)) do
      [] -> :ok
      missing -> {:error, {:missing_args, missing}}
    end
  end
end
