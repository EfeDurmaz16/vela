defmodule VelaWeb.EvidencePageComponents do
  @moduledoc """
  Evidence ledger rendering for the app LiveView.
  """

  use VelaWeb, :html

  attr :evidence_events, :list, default: []

  def evidence_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header title="Evidence Ledger" kicker="Can we reconstruct what happened?" />
      <div class="panel p-5">
        <div class="mb-4 flex flex-wrap gap-2 text-xs text-muted-fg">
          <span class="rounded-md border border-border px-2 py-1">actor</span>
          <span class="rounded-md border border-border px-2 py-1">repo</span>
          <span class="rounded-md border border-border px-2 py-1">event type</span>
          <span class="rounded-md border border-border px-2 py-1">hash chain</span>
        </div>
        <div class="divide-y divide-border">
          <.evidence_item :for={event <- @evidence_events} event={event} />
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :kicker, :string, required: true

  defp section_header(assigns) do
    ~H"""
    <section>
      <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted-fg">{@kicker}</p>
      <h1 class="mt-2 text-3xl font-semibold tracking-tight text-fg">{@title}</h1>
    </section>
    """
  end
end
