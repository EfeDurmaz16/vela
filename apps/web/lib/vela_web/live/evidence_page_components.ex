defmodule VelaWeb.EvidencePageComponents do
  @moduledoc """
  Evidence ledger rendering for the app LiveView.
  """

  use VelaWeb, :html

  attr :evidence_events, :list, default: []
  attr :verifier_statuses, :list, default: []

  def evidence_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header title="Evidence Ledger" kicker="Can we reconstruct what happened?" />
      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <div :for={status <- @verifier_statuses} class="panel p-5">
          <p class="text-xs font-semibold uppercase tracking-[0.14em] text-muted-fg">
            {status.repository}
          </p>
          <p class={["mt-3 text-lg font-semibold", verifier_class(status.state)]}>
            {status.label}
          </p>
          <p class="mt-2 text-sm text-muted-fg">{status.detail}</p>
        </div>
      </div>
      <div class="panel p-5">
        <div class="mb-4 flex flex-wrap gap-2 text-xs text-muted-fg">
          <span class="rounded-md border border-border px-2 py-1">actor</span>
          <span class="rounded-md border border-border px-2 py-1">repo</span>
          <span class="rounded-md border border-border px-2 py-1">event type</span>
          <span class="rounded-md border border-border px-2 py-1">hash chain</span>
        </div>
        <div :if={@evidence_events == []} class="rounded-lg border border-border bg-bg p-4">
          <p class="text-sm font-medium text-fg">No evidence events yet</p>
          <p class="mt-1 text-sm text-muted-fg">
            Append the first trusted action before relying on the ledger for reconstruction.
          </p>
        </div>
        <div :if={@evidence_events != []} class="divide-y divide-border">
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

  defp verifier_class(:healthy), do: "text-success"
  defp verifier_class(:empty), do: "text-muted-fg"
  defp verifier_class(:tampered), do: "text-danger"
end
