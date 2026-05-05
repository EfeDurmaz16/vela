defmodule Vela.Storage.ObjectStore do
  @moduledoc "Artifact, log, analysis output, and release object storage boundary."

  @callback put_object(map()) :: {:ok, map()} | {:error, term()}
  @callback get_object(map()) :: {:ok, binary()} | {:error, term()}
  @callback presign_get(map()) :: {:ok, URI.t()} | {:error, term()}
end
