defmodule Vela.Integrations do
  @moduledoc """
  Boundaries for WorkOS, GitHub import/mirror, webhooks, and future external integrations.

  Phase 0 intentionally exposes documentation-backed placeholders only.
  """

  def phase_zero_status do
    %{
      workos: "interface-defined",
      github_import: "interface-defined",
      webhooks: "interface-defined",
      production_auth: "planned-phase-1"
    }
  end
end
