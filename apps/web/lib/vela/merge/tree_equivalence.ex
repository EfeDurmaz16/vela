defmodule Vela.Merge.TreeEquivalence do
  @moduledoc """
  Classifies merge-candidate tree equivalence state.

  The merge queue tracks three distinct tree concepts:

  - virtual merge tree: the tree produced by simulation
  - tested tree: the tree that readiness evidence was produced against
  - final merge tree: the tree that would actually land
  """

  @states ~w(unmerged untested tested equivalent mismatch)

  def states, do: @states

  def classify(attrs) do
    virtual = fetch(attrs, :virtual_merge_tree_hash)
    tested = fetch(attrs, :tested_tree_hash)
    final = fetch(attrs, :final_merge_tree_hash)

    cond do
      blank?(virtual) ->
        "unmerged"

      blank?(tested) ->
        "untested"

      blank?(final) ->
        "tested"

      tested == final ->
        "equivalent"

      true ->
        "mismatch"
    end
  end

  def equivalent?(attrs), do: classify(attrs) == "equivalent"
  def mismatch?(attrs), do: classify(attrs) == "mismatch"

  defp fetch(%{} = attrs, key), do: Map.get(attrs, key) || Map.get(attrs, to_string(key))
  defp fetch(struct, key), do: Map.get(struct, key)

  defp blank?(value), do: !is_binary(value) or String.trim(value) == ""
end
