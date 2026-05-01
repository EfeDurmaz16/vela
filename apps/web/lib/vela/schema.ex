defmodule Vela.Schema do
  @moduledoc """
  Shared schema defaults for Vela control-plane records.
  """

  defmacro __using__(_) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
