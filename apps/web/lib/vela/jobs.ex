defmodule Vela.Jobs do
  @moduledoc """
  Oban job constructors for expensive request-path work.
  """

  @domains [
    Vela.Jobs.RepositoryJobs,
    Vela.Jobs.AnalysisJobs,
    Vela.Jobs.ScoringJobs,
    Vela.Jobs.MergeJobs
  ]

  def new(kind, attrs) when is_atom(kind) do
    worker = worker!(kind)
    args = attrs |> stringify_keys() |> Map.put("kind", to_string(kind))
    worker.new(args)
  end

  def enqueue(kind, attrs), do: kind |> new(attrs) |> Oban.insert()

  def workers do
    @domains
    |> Enum.map(& &1.workers())
    |> Enum.reduce(%{}, &Map.merge/2)
  end

  defp worker!(kind) do
    @domains
    |> Enum.find_value(fn domain ->
      case domain.worker(kind) do
        {:ok, worker} -> worker
        :error -> nil
      end
    end)
    |> case do
      nil -> raise KeyError, key: kind, term: workers()
      worker -> worker
    end
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
