defmodule VelaWeb.AppLive do
  use VelaWeb, :live_view

  alias Vela.{Agents, Evidence, Forge, Integrations}
  import VelaWeb.AppShellComponents
  import VelaWeb.EvidencePageComponents
  import VelaWeb.PullRequestPageComponents
  import VelaWeb.RepositoryPageComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_common(socket)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign_common()
      |> assign_page(params)

    {:noreply, socket}
  end

  defp assign_common(socket) do
    assign(socket,
      repositories: Forge.list_repositories(),
      active_prs: Forge.active_pull_requests(),
      pull_requests: Forge.list_pull_requests(),
      agents: Agents.list_agent_profiles(),
      sessions: Agents.list_recent_sessions(),
      evidence_events: Evidence.list_recent_events(20),
      integration_status: Integrations.phase_zero_status()
    )
  end

  defp assign_page(%{assigns: %{live_action: :repo}} = socket, %{"org" => org, "repo" => repo}) do
    assign(socket,
      repository: Forge.get_repository_by_slugs!(org, repo),
      page_title: "Repository"
    )
  end

  defp assign_page(%{assigns: %{live_action: :pull}} = socket, %{
         "org" => org,
         "repo" => repo,
         "id" => id
       }) do
    pr = Forge.get_pull_request_for_route!(org, repo, id)

    assign(socket,
      pull_request: pr,
      score: Forge.latest_score(pr),
      merge_candidate: Forge.latest_merge_candidate(pr),
      page_title: "PR Cockpit"
    )
  end

  defp assign_page(%{assigns: %{live_action: :agent_profile}} = socket, %{"id" => id}) do
    assign(socket, agent: Agents.get_agent_profile!(id), page_title: "Agent Profile")
  end

  defp assign_page(socket, _params),
    do: assign(socket, page_title: title_for(socket.assigns.live_action))

  defp title_for(:home), do: "Home"
  defp title_for(:repos), do: "Repositories"
  defp title_for(:agents), do: "Agents"
  defp title_for(:launches), do: "Launches"
  defp title_for(:evidence), do: "Evidence"
  defp title_for(:settings), do: "Settings"
  defp title_for(_), do: "Vela"

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell live_action={@live_action} page_title={@page_title} active_prs={@active_prs}>
      <.page {assigns} />
    </.app_shell>
    """
  end

  defp page(%{live_action: :home} = assigns) do
    ~H"""
    <div class="space-y-6">
      <section class="grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
        <div class="panel p-6">
          <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted-fg">
            Product thesis
          </p>
          <h1 class="mt-4 max-w-3xl text-4xl font-semibold tracking-tight text-fg">
            GitHub stores code. Vela proves whether code can be trusted.
          </h1>
          <p class="mt-4 max-w-2xl text-sm leading-6 text-muted-fg">
            Vela combines actor identity, agent provenance, deterministic merge metadata, launch readiness scoring, policy gates, and an append-only evidence ledger around every change.
          </p>
        </div>
        <div class="panel p-6">
          <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted-fg">
            Trust attention
          </p>
          <div class="mt-5 grid grid-cols-2 gap-3">
            <.metric label="Repos" value={length(@repositories)} meta="private forge demo" />
            <.metric label="Active PRs" value={length(@active_prs)} meta="ship and block examples" />
          </div>
        </div>
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <div class="lg:col-span-2 panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Active Pull Requests
          </h2>
          <div class="mt-4 divide-y divide-border">
            <div
              :for={pr <- @active_prs}
              class="flex flex-col gap-3 py-4 md:flex-row md:items-center md:justify-between"
            >
              <div>
                <.link navigate={pull_href(pr)} class="font-medium text-fg hover:underline">
                  {pr.title}
                </.link>
                <p class="mt-1 text-sm text-muted-fg">
                  {pr.repository.name} · {pr.author_actor.display_name}
                </p>
              </div>
              <div class="flex items-center gap-3">
                <% score = Forge.latest_score(pr) %>
                <.verdict_badge verdict={score.verdict} />
                <span class="text-sm font-semibold">{score.overall_score}</span>
              </div>
            </div>
          </div>
        </div>
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Recent Evidence
          </h2>
          <div class="mt-3 divide-y divide-border">
            <.evidence_item :for={event <- Enum.take(@evidence_events, 4)} event={event} />
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp page(%{live_action: :repos} = assigns) do
    ~H"""
    <.repositories_page repositories={@repositories} />
    """
  end

  defp page(%{live_action: :repo} = assigns) do
    ~H"""
    <.repository_page repository={@repository} />
    """
  end

  defp page(%{live_action: :pull} = assigns) do
    ~H"""
    <.pull_request_page
      pull_request={@pull_request}
      score={@score}
      merge_candidate={@merge_candidate}
    />
    """
  end

  defp page(%{live_action: :agents} = assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header
        title="Agents"
        kicker="Which machine actors are active, trusted, risky, or blocked?"
      />
      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        <.link
          :for={agent <- @agents}
          navigate={~p"/agents/#{agent.id}"}
          class="panel block p-5 hover:border-fg/30"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="font-semibold">{agent.display_name}</p>
              <p class="mt-1 text-sm text-muted-fg">
                {agent.agent_identity && agent.agent_identity.did}
              </p>
            </div>
            <span class="text-sm font-semibold">
              {agent.agent_identity && agent.agent_identity.trust_score}
            </span>
          </div>
          <p class="mt-4 text-sm text-muted-fg">
            {length(agent.agent_sessions)} sessions · {length(agent.agent_policies)} policies
          </p>
        </.link>
      </div>
    </div>
    """
  end

  defp page(%{live_action: :agent_profile} = assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header
        title={@agent.display_name}
        kicker="Can this actor be trusted with the permissions it has?"
      />
      <section class="grid gap-4 md:grid-cols-4">
        <.metric label="Type" value={@agent.type} meta="first-class actor" />
        <.metric label="Trust" value={@agent.trust_level} meta="registry status" />
        <.metric label="Score" value={@agent.agent_identity.trust_score} meta="agent trust profile" />
        <.metric label="Sessions" value={length(@agent.agent_sessions)} meta="auditable work" />
      </section>
      <section class="grid gap-4 lg:grid-cols-2">
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">Identity</h2>
          <p class="mt-4 font-mono text-sm text-fg">{@agent.agent_identity.did}</p>
          <p class="mt-2 font-mono text-xs text-muted-fg">{@agent.agent_identity.public_key}</p>
        </div>
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Policy Scope
          </h2>
          <div :for={policy <- @agent.agent_policies} class="mt-4 text-sm text-muted-fg">
            <p class="font-medium text-fg">{policy.name}</p>
            <p class="mt-2">Allowed paths: {Enum.join(policy.allowed_paths, ", ")}</p>
            <p class="mt-1">Forbidden paths: {Enum.join(policy.forbidden_paths, ", ")}</p>
            <p class="mt-1">
              Can merge: {policy.can_merge} · Human approval: {policy.requires_human_approval}
            </p>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp page(%{live_action: :launches} = assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header title="Launch Cockpit" kicker="Can this release candidate ship?" />
      <div class="grid gap-4">
        <div :for={pr <- @active_prs} class="panel p-5">
          <% score = Forge.latest_score(pr) %>
          <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <.verdict_badge verdict={score.verdict} />
              <h2 class="mt-3 text-xl font-semibold">{pr.title}</h2>
              <p class="mt-2 text-sm text-muted-fg">
                {pr.repository.name} · included PR · API/security/performance sections are interface-defined in Phase 0.
              </p>
            </div>
            <div class="w-full md:w-64">
              <.score_bar score={score.overall_score} label="Readiness" />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp page(%{live_action: :evidence} = assigns) do
    ~H"""
    <.evidence_page evidence_events={@evidence_events} />
    """
  end

  defp page(%{live_action: :settings} = assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_header title="Settings" kicker="What controls trust and access?" />
      <section class="grid gap-4 md:grid-cols-2">
        <.simple_list
          title="Organization Controls"
          items={[
            %{
              title: "WorkOS",
              body: "AuthKit, organizations, SSO and SCIM are interface-defined for Phase 1."
            },
            %{
              title: "Branch protection",
              body: "Protected main branches exist in schema and seed data."
            },
            %{title: "Billing", body: "Placeholder only; no billing flow is implemented in Phase 0."}
          ]}
        />
        <.simple_list
          title="Integration Status"
          items={Enum.map(@integration_status, fn {k, v} -> %{title: to_string(k), body: v} end)}
        />
      </section>
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
