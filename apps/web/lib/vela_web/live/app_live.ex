defmodule VelaWeb.AppLive do
  use VelaWeb, :live_view

  alias Vela.{Agents, Evidence, Forge, Integrations}

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
          <.page {assigns} />
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

  defp page(%{live_action: :repo} = assigns) do
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

  defp page(%{live_action: :pull} = assigns) do
    ~H"""
    <div class="space-y-6">
      <.status_banner
        verdict={@score.verdict}
        title={@pull_request.title}
        body={@score.explanation}
      />

      <section class="grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
        <div class="panel p-5">
          <.score_bar score={@score.overall_score} />
          <div class="mt-5 grid grid-cols-2 gap-3 text-sm">
            <.score_cell label="Behavioral" value={@score.behavioral_score} />
            <.score_cell label="Correctness" value={@score.correctness_score} />
            <.score_cell label="Security" value={@score.security_score} />
            <.score_cell label="Performance" value={@score.performance_score} />
            <.score_cell label="UX" value={@score.ux_score} />
            <.score_cell label="Agent provenance" value={@score.agent_provenance_score} />
          </div>
        </div>
        <div class="panel p-5">
          <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">
            Behavioral Summary
          </h2>
          <p class="mt-4 text-sm leading-6 text-fg">{@pull_request.behavioral_summary}</p>
          <p class="mt-4 text-sm leading-6 text-muted-fg">{@pull_request.intent}</p>
        </div>
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <.simple_list title="Risk Map" items={risk_items(@score, @pull_request)} />
        <.simple_list title="Test Evidence" items={test_items(@score)} />
        <.simple_list title="Agent Provenance" items={agent_items(@pull_request.author_actor)} />
      </section>

      <section class="grid gap-4 lg:grid-cols-3">
        <.simple_list title="Review Requirements" items={review_items(@pull_request)} />
        <.simple_list title="Merge Simulation" items={merge_items(@merge_candidate)} />
        <.simple_list title="Rollback Plan" items={rollback_items(@merge_candidate)} />
      </section>

      <div class="panel p-5">
        <h2 class="text-sm font-semibold uppercase tracking-[0.14em] text-muted-fg">Raw Code Diff</h2>
        <pre class="mt-4 overflow-auto rounded-lg border border-border bg-bg p-4 text-xs text-muted-fg"><code>Interface defined. Phase 0 uses mock-backed diff metadata.

        @@ policy/agent_spending_policy.ex
        + enforce fail-closed policy decision before delegated spending action
        + append policy.evaluated evidence event

        @@ test/policy/agent_spending_policy_test.exs
        + covers blocked path scope and missing approval cases</code></pre>
      </div>
    </div>
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

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp score_cell(assigns) do
    ~H"""
    <div class="rounded-md border border-border p-3">
      <p class="text-xs uppercase tracking-[0.12em] text-muted-fg">{@label}</p>
      <p class="mt-2 text-xl font-semibold text-fg">{@value}</p>
    </div>
    """
  end

  defp first_pull_href([]), do: "/repos"
  defp first_pull_href([pr | _]), do: pull_href(pr)

  defp pull_href(pr),
    do: "/repos/#{pr.repository.organization.slug}/#{pr.repository.slug}/pulls/#{pr.id}"

  defp risk_items(score, pr) do
    findings =
      Enum.map(score.blocking_findings, fn finding ->
        %{title: finding["severity"] || "risk", body: finding["message"] || inspect(finding)}
      end)

    if findings == [] do
      [
        %{
          title: "Bounded #{pr.risk_level} risk",
          body:
            "No blocking findings. Security #{score.security_score}, correctness #{score.correctness_score}."
        },
        %{
          title: "Policy-aware score",
          body: "The score is evaluated with repository profile weighting."
        }
      ]
    else
      findings
    end
  end

  defp test_items(score) do
    [
      %{
        title: "Test evidence #{score.test_evidence_score}",
        body: Enum.join(score.required_actions, " ")
      },
      %{
        title: "Runner model",
        body: "BYO runner metadata exists; hosted CI is intentionally deferred."
      }
    ]
  end

  defp agent_items(actor) do
    [
      %{
        title: actor.display_name,
        body: "Actor type #{actor.type}, trust level #{actor.trust_level}."
      },
      %{
        title: "Signed events",
        body:
          "Signing key reference is registered; cryptographic verification lands after Phase 0."
      }
    ]
  end

  defp review_items(pr) do
    Enum.map(pr.reviews, fn review ->
      %{title: review.status, body: review.summary || "Review recorded."}
    end)
    |> then(fn items ->
      if items == [],
        do: [%{title: "Human review required", body: "No approving review has been recorded."}],
        else: items
    end)
  end

  defp merge_items(candidate) do
    [
      %{
        title: "Status #{candidate.status}",
        body: "Virtual tree #{candidate.virtual_merge_tree_hash || "not computed"}."
      },
      %{
        title: "Tree equivalence",
        body:
          "tested=#{candidate.tested_tree_hash || "missing"} final=#{candidate.final_merge_tree_hash || "pending"}"
      }
    ]
  end

  defp rollback_items(candidate) do
    candidate.rollback_plan
    |> Enum.map(fn {key, value} -> %{title: to_string(key), body: inspect(value)} end)
  end
end
