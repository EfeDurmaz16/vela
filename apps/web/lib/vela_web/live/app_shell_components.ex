defmodule VelaWeb.AppShellComponents do
  @moduledoc """
  Shell and navigation components for the main Vela LiveView surface.
  """

  use VelaWeb, :html

  attr :live_action, :atom, required: true
  attr :page_title, :string, required: true
  attr :active_prs, :list, default: []
  slot :inner_block, required: true

  def app_shell(assigns) do
    ~H"""
    <div class="min-h-screen bg-bg text-fg">
      <aside class="fixed inset-y-0 left-0 hidden w-64 border-r border-border bg-panel px-4 py-5 lg:block">
        <div class="mb-8">
          <p class="text-lg font-semibold tracking-tight">Vela</p>
          <p class="mt-1 text-xs text-muted-fg">The AI-native forge for trusted software.</p>
        </div>
        <nav class="space-y-1">
          <.nav_item href={~p"/"} active={@live_action == :home} label="Home" />
          <.nav_item
            href={~p"/repos"}
            active={@live_action in [:repos, :repo, :pull]}
            label="Repositories"
          />
          <.nav_item
            href={first_pull_href(@active_prs)}
            active={@live_action == :pull}
            label="Pull Requests"
          />
          <.nav_item href={~p"/launches"} active={@live_action == :launches} label="Launches" />
          <.nav_item
            href={~p"/agents"}
            active={@live_action in [:agents, :agent_profile]}
            label="Agents"
          />
          <.nav_item href={~p"/repos"} active={false} label="Issues" />
          <.nav_item href={~p"/evidence"} active={@live_action == :evidence} label="Evidence" />
          <.nav_item href={~p"/settings"} active={@live_action == :settings} label="Settings" />
        </nav>
        <div class="absolute bottom-5 left-4 right-4 rounded-lg border border-border bg-bg p-3">
          <p class="text-xs font-semibold uppercase tracking-[0.14em] text-muted-fg">Phase 0</p>
          <p class="mt-2 text-sm text-fg">Interface-defined, mock-backed Git and Maestro services.</p>
        </div>
      </aside>

      <div class="lg:pl-64">
        <header class="sticky top-0 z-10 border-b border-border bg-bg/90 px-5 py-4 backdrop-blur">
          <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted-fg">
                Sardis Labs
              </p>
              <p class="mt-1 text-lg font-semibold">{@page_title}</p>
            </div>
            <div class="flex flex-wrap gap-2 text-xs text-muted-fg">
              <span class="rounded-md border border-border px-2 py-1">WorkOS boundary</span>
              <span class="rounded-md border border-border px-2 py-1">Postgres canonical</span>
              <span class="rounded-md border border-border px-2 py-1">Evidence hash chain</span>
            </div>
          </div>
        </header>

        <main class="mx-auto max-w-7xl px-5 py-6">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "block rounded-md px-3 py-2 text-sm font-medium",
        if(@active, do: "bg-fg text-bg", else: "text-muted-fg hover:bg-bg hover:text-fg")
      ]}
    >
      {@label}
    </.link>
    """
  end

  defp first_pull_href([]), do: "/repos"

  defp first_pull_href([pr | _]) do
    "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}"
  end
end
