defmodule VelaWeb.TrustComponents do
  @moduledoc """
  Focused Phase 0 components for Vela's trust cockpit surfaces.
  """

  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :meta, :string, default: nil

  def metric(assigns) do
    ~H"""
    <div class="panel p-4">
      <p class="text-xs font-medium uppercase tracking-[0.14em] text-muted-fg">{@label}</p>
      <p class="mt-3 text-3xl font-semibold text-fg">{@value}</p>
      <p :if={@meta} class="mt-2 text-sm text-muted-fg">{@meta}</p>
    </div>
    """
  end

  attr :verdict, :string, required: true

  def verdict_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-md px-2 py-1 text-xs font-semibold uppercase tracking-[0.12em]",
      verdict_class(@verdict)
    ]}>
      {@verdict}
    </span>
    """
  end

  attr :score, :integer, required: true
  attr :label, :string, default: "Launch Readiness"

  def score_bar(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-end justify-between gap-4">
        <div>
          <p class="text-xs font-medium uppercase tracking-[0.14em] text-muted-fg">{@label}</p>
          <p class="mt-1 text-sm text-muted-fg">Policy-aware confidence signal.</p>
        </div>
        <p class="text-4xl font-semibold text-fg">{@score}</p>
      </div>
      <div class="h-2 overflow-hidden rounded-full bg-border">
        <div class={["h-full rounded-full", score_fill(@score)]} style={"width: #{@score}%"} />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :verdict, :string, required: true

  def status_banner(assigns) do
    ~H"""
    <section class={["panel p-5", banner_border(@verdict)]}>
      <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
        <div>
          <div class="mb-3"><.verdict_badge verdict={@verdict} /></div>
          <h1 class="max-w-4xl text-2xl font-semibold text-fg md:text-3xl">{@title}</h1>
          <p class="mt-3 max-w-3xl text-sm leading-6 text-muted-fg">{@body}</p>
        </div>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  def simple_list(assigns) do
    ~H"""
    <div class="panel p-5">
      <h2 class="text-sm font-semibold uppercase tracking-[0.12em] text-muted-fg">{@title}</h2>
      <div class="mt-4 space-y-3">
        <div :for={item <- @items} class="border-b border-border pb-3 last:border-b-0 last:pb-0">
          <p class="text-sm font-medium text-fg">{item[:title] || item["title"]}</p>
          <p class="mt-1 text-sm text-muted-fg">{item[:body] || item["body"]}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :event, :map, required: true

  def evidence_item(assigns) do
    ~H"""
    <div class="grid gap-2 border-b border-border py-4 last:border-b-0 md:grid-cols-[180px_1fr]">
      <div>
        <p class="text-xs font-semibold uppercase tracking-[0.12em] text-muted-fg">
          {@event.event_type}
        </p>
        <p class="mt-1 text-xs text-muted-fg">{@event.actor.display_name}</p>
      </div>
      <div>
        <p class="text-sm text-fg">
          {@event.resource_type} <span class="text-muted-fg">/{short_id(@event.resource_id)}</span>
        </p>
        <p class="mt-2 font-mono text-xs text-muted-fg">hash {short_hash(@event.event_hash)}</p>
        <p class="mt-1 font-mono text-xs text-muted-fg">
          prev {short_hash(@event.prev_event_hash || "genesis")}
        </p>
      </div>
    </div>
    """
  end

  def short_id(nil), do: "none"
  def short_id(value), do: value |> to_string() |> String.slice(0, 8)

  def short_hash(nil), do: "none"
  def short_hash("genesis"), do: "genesis"
  def short_hash(hash), do: hash |> String.replace_prefix("sha256:", "") |> String.slice(0, 12)

  defp verdict_class("ship"), do: "bg-success/10 text-success"
  defp verdict_class("wait"), do: "bg-warning/10 text-warning"
  defp verdict_class("block"), do: "bg-danger/10 text-danger"
  defp verdict_class(_), do: "bg-muted text-muted-fg"

  defp banner_border("ship"), do: "border-success/30"
  defp banner_border("wait"), do: "border-warning/30"
  defp banner_border("block"), do: "border-danger/30"
  defp banner_border(_), do: "border-border"

  defp score_fill(score) when score >= 75, do: "bg-success"
  defp score_fill(score) when score >= 60, do: "bg-warning"
  defp score_fill(_score), do: "bg-danger"
end
