defmodule VelaWeb.AppLive do
  use VelaWeb, :live_view

  alias Vela.{Accounts, Actors, Agents, Evidence, Forge, Integrations, Jobs, Repo}
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
      integration_status: Integrations.phase_zero_status(),
      import_form: %{"owner" => "", "repo" => ""},
      import_error: nil,
      comment_form: %{"body" => "", "publish_to_github" => "false"},
      comment_error: nil
    )
  end

  @impl true
  def handle_event("import_repository", %{"import" => params}, socket) do
    case queue_repository_import(params) do
      {:ok, repository, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Repository import queued for #{repository.full_name}.")
         |> push_navigate(to: ~p"/repos/#{repository.organization.slug}/#{repository.slug}")}

      {:error, :missing_fields} ->
        {:noreply,
         socket
         |> put_flash(:error, "Owner and repository are required.")
         |> assign(:import_form, params)
         |> assign(:import_error, "Owner and repository are required.")}

      {:error, :missing_workspace} ->
        {:noreply, put_flash(socket, :error, "No organization and actor are available.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Repository import could not be queued.")
         |> assign(:import_form, params)
         |> assign(:import_error, "Repository import could not be queued.")
         |> assign(:import_errors, changeset)}
    end
  end

  def handle_event("create_pr_comment", %{"comment" => params}, socket) do
    case create_pr_comment(socket.assigns.pull_request, params) do
      {:ok, _review} ->
        {:noreply,
         socket
         |> put_flash(:info, "Review comment recorded.")
         |> assign(:pull_request, refresh_pull_request(socket.assigns.pull_request))
         |> assign(:comment_form, %{"body" => "", "publish_to_github" => "false"})
         |> assign(:comment_error, nil)}

      {:error, :missing_body} ->
        {:noreply,
         socket
         |> put_flash(:error, "Comment body is required.")
         |> assign(:comment_form, params)
         |> assign(:comment_error, "Comment body is required.")}

      {:error, :missing_workspace} ->
        {:noreply, put_flash(socket, :error, "No actor is available for review comments.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Review comment could not be recorded.")
         |> assign(:comment_form, params)
         |> assign(:comment_error, "Review comment could not be recorded.")}
    end
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
    <.repositories_page
      repositories={@repositories}
      import_form={@import_form}
      import_error={@import_error}
    />
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
      comment_form={@comment_form}
      comment_error={@comment_error}
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

  defp queue_repository_import(params) do
    owner = params |> Map.get("owner", "") |> String.trim()
    repo_name = params |> Map.get("repo", "") |> String.trim()

    with :ok <- require_import_fields(owner, repo_name),
         {:ok, organization, actor} <- import_workspace(),
         {:ok, repository, job} <- upsert_import_repository(organization, actor, owner, repo_name) do
      {:ok, Repo.preload(repository, :organization), job}
    end
  end

  defp require_import_fields("", _repo_name), do: {:error, :missing_fields}
  defp require_import_fields(_owner, ""), do: {:error, :missing_fields}
  defp require_import_fields(_owner, _repo_name), do: :ok

  defp import_workspace do
    with %{} = organization <- Accounts.list_organizations() |> List.first(),
         %{} = actor <- organization.id |> Actors.list_actors() |> List.first() do
      {:ok, organization, actor}
    else
      _ -> {:error, :missing_workspace}
    end
  end

  defp upsert_import_repository(organization, actor, owner, repo_name) do
    Repo.transaction(fn ->
      with {:ok, repository} <- upsert_import_placeholder(organization, owner, repo_name),
           {:ok, job} <- enqueue_import_job(repository, owner, repo_name),
           {:ok, _event} <- append_import_event(repository, actor, job) do
        {repository, job}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, {repository, job}} -> {:ok, repository, job}
      {:error, reason} -> {:error, reason}
    end
  end

  defp upsert_import_placeholder(organization, owner, repo_name) do
    slug = repo_name |> String.downcase()

    attrs = %{
      organization_id: organization.id,
      name: repo_name,
      slug: slug,
      visibility: "private",
      default_branch: "main",
      description: "GitHub import pending for #{owner}/#{repo_name}.",
      provider: "github",
      full_name: "#{owner}/#{repo_name}",
      import_status: "pending",
      last_import_error: nil,
      health_status: "unknown",
      risk_level: "medium"
    }

    case Forge.get_repository_by_slug_for_org(organization.id, slug) do
      nil -> Forge.create_repository(attrs)
      repository -> Forge.update_repository(repository, attrs)
    end
  end

  defp enqueue_import_job(repository, owner, repo_name) do
    Jobs.enqueue(:repo_import, %{
      organization_id: repository.organization_id,
      repository_id: repository.id,
      provider: "github",
      owner: owner,
      repo: repo_name
    })
  end

  defp append_import_event(repository, actor, job) do
    Evidence.append_event(%{
      organization_id: repository.organization_id,
      repository_id: repository.id,
      actor_id: actor.id,
      event_type: "repo.import_queued",
      resource_type: "repository",
      resource_id: repository.id,
      payload: %{
        job_id: job.id,
        job_queue: job.queue,
        owner: repository.full_name
      }
    })
  end

  defp create_pr_comment(pull_request, params) do
    body = params |> Map.get("body", "") |> String.trim()
    publish_to_github? = Map.get(params, "publish_to_github") == "true"

    with :ok <- require_comment_body(body),
         {:ok, _organization, actor} <- import_workspace(),
         {:ok, review} <- Forge.create_review(comment_attrs(pull_request, actor, body)),
         {:ok, _event} <- append_pr_comment_event(pull_request, actor, review, publish_to_github?) do
      {:ok, review}
    end
  end

  defp require_comment_body(""), do: {:error, :missing_body}
  defp require_comment_body(_body), do: :ok

  defp comment_attrs(pull_request, actor, body) do
    %{
      pull_request_id: pull_request.id,
      actor_id: actor.id,
      status: "comment",
      summary: body,
      submitted_at: DateTime.utc_now(:second)
    }
  end

  defp append_pr_comment_event(pull_request, actor, review, publish_to_github?) do
    Evidence.append_event(%{
      organization_id: pull_request.repository.organization_id,
      repository_id: pull_request.repository_id,
      actor_id: actor.id,
      event_type: "pr.updated",
      resource_type: "pull_request",
      resource_id: pull_request.id,
      payload: %{
        action: "review_comment_created",
        review_id: review.id,
        publish_to_github: publish_to_github?
      }
    })
  end

  defp refresh_pull_request(pull_request) do
    Forge.get_pull_request_for_route!(
      pull_request.repository.organization.slug,
      pull_request.repository.slug,
      pull_request.id
    )
  end
end
