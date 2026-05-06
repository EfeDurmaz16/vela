defmodule VelaWeb.RepositoryPageComponents do
  @moduledoc """
  Repository list and repository overview rendering for the app LiveView.
  """

  use VelaWeb, :html

  alias Vela.{Evidence, Forge}

  attr :repositories, :list, required: true

  def repositories_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header
        title="Repositories"
        kicker="Which repositories are healthy, risky, or waiting on action?"
      />
      <div class="panel overflow-hidden">
        <table class="w-full text-left text-sm">
          <thead class="border-b border-border text-xs uppercase tracking-[0.12em] text-muted-fg">
            <tr>
              <th class="px-5 py-3">Repository</th>
              <th class="px-5 py-3">Health</th>
              <th class="px-5 py-3">Risk</th>
              <th class="px-5 py-3">Active PRs</th>
              <th class="px-5 py-3">Cell</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-border">
            <tr :for={repo <- @repositories}>
              <td class="px-5 py-4">
                <.link
                  navigate={~p"/repos/#{repo.organization.slug}/#{repo.slug}"}
                  class="font-medium hover:underline"
                >
                  {repo.name}
                </.link>
                <p class="mt-1 text-muted-fg">{repo.description}</p>
              </td>
              <td class="px-5 py-4">{repo.health_status}</td>
              <td class="px-5 py-4">{repo.risk_level}</td>
              <td class="px-5 py-4">{length(repo.pull_requests)}</td>
              <td class="px-5 py-4 font-mono text-xs text-muted-fg">{repo.repo_cell_id}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :repository, :map, required: true

  def repository_page(assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header
        title={@repository.name}
        kicker="Can I trust the current state of this repository?"
      />
      <section class="grid gap-4 md:grid-cols-4">
        <.metric label="Health" value={@repository.health_status} meta="main branch integrity" />
        <.metric label="Risk" value={@repository.risk_level} meta="current hotspot level" />
        <.metric label="Active PRs" value={length(@repository.pull_requests)} meta="review queue" />
        <.metric
          label="Cell"
          value={@repository.repo_cell_id || "unassigned"}
          meta="future repo placement"
        />
      </section>
      <section class="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Pull Requests
          </h2>
          <div class="mt-4 divide-y divide-border">
            <div
              :for={pr <- @repository.pull_requests}
              class="flex items-center justify-between gap-4 py-4"
            >
              <div>
                <.link navigate={pull_href(pr)} class="font-medium hover:underline">{pr.title}</.link>
                <p class="mt-1 text-sm text-muted-fg">{pr.behavioral_summary}</p>
              </div>
              <% score = Forge.latest_score(pr) %>
              <.verdict_badge verdict={score.verdict} />
            </div>
          </div>
        </div>
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Latest Evidence
          </h2>
          <div class="mt-3 divide-y divide-border">
            <.evidence_item
              :for={event <- Evidence.list_repository_events(@repository.id, 5)}
              event={event}
            />
          </div>
        </div>
      </section>
      <div class="panel p-5">
        <p class="text-xs font-semibold uppercase tracking-[0.14em] text-muted-fg">Tabs</p>
        <p class="mt-3 text-sm text-muted-fg">
          Overview · Code · Pull Requests · Issues · Agents · Pipelines · Launches · Insights · Settings. Phase 0 renders overview and cockpit data; remaining tabs are interface-defined.
        </p>
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

  defp pull_href(pr),
    do: "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}"
end
