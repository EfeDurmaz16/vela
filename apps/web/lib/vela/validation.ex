defmodule Vela.Validation do
  @moduledoc false

  import Ecto.Changeset

  def validate_inclusion(changeset, field, allowed) do
    validate_change(changeset, field, fn ^field, value ->
      if value in allowed, do: [], else: [{field, "is invalid"}]
    end)
  end

  def validate_score(changeset, field) do
    changeset
    |> validate_number(field, greater_than_or_equal_to: 0)
    |> validate_number(field, less_than_or_equal_to: 100)
  end
end
