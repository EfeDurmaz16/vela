defmodule Vela.InterfacesTest do
  use ExUnit.Case, async: true

  test "foundation exposes named sidecar and external-service behaviours" do
    for module <- [
          Vela.Git.GitProvider,
          Vela.Git.RepoImporter,
          Vela.Git.RefService,
          Vela.Git.DiffService,
          Vela.Git.MergeSimulator,
          Vela.Storage.ObjectStore,
          Vela.Auth.WorkOS,
          Vela.Agents.SignatureVerifier
        ] do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :behaviour_info, 1)
    end
  end
end
