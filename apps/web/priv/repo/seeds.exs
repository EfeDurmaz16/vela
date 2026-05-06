alias Vela.Accounts
alias Vela.Actors
alias Vela.Agents
alias Vela.Evidence
alias Vela.Forge
alias Vela.Maestro
alias Vela.Merge
alias Vela.Pipelines
alias Vela.Repo

for schema <- [
      Vela.Outbox.OutboxEvent,
      Vela.Idempotency.IdempotencyKey,
      Vela.Auth.ApiToken,
      Vela.Evidence.TamperAlarm,
      Vela.Forge.RepositoryTrustSignal,
      Vela.Forge.CheckRun,
      Vela.Integrations.ServiceConnection,
      Vela.Integrations.Environment,
      Vela.Integrations.Integration,
      Vela.Releases.ReleaseCandidate,
      Vela.Maestro.ReadinessScore,
      Vela.Forge.Change,
      Vela.Pipelines.PipelineJob,
      Vela.Pipelines.PipelineRun,
      Vela.Pipelines.Runner,
      Vela.Agents.AgentPolicy,
      Vela.Evidence.EvidenceEvent,
      Vela.Merge.MergeCandidate,
      Vela.Maestro.LaunchReadinessScore,
      Vela.Maestro.AnalysisRun,
      Vela.Agents.AgentSession,
      Vela.Forge.Issue,
      Vela.Forge.Review,
      Vela.Forge.PullRequest,
      Vela.Forge.Branch,
      Vela.Forge.Repository,
      Vela.Agents.AgentIdentity,
      Vela.Actors.Actor,
      Vela.Accounts.Membership,
      Vela.Accounts.User,
      Vela.Accounts.Organization
    ] do
  Repo.delete_all(schema)
end

now = DateTime.utc_now() |> DateTime.truncate(:second)

{:ok, org} =
  Accounts.create_organization(%{
    name: "Sardis Labs",
    slug: "sardis-labs",
    plan: "team",
    workos_org_id: "org_demo_sardis_labs"
  })

{:ok, efe} =
  Accounts.create_user(%{
    email: "efe@sardislabs.dev",
    name: "Efe",
    avatar_url: "https://avatars.githubusercontent.com/u/1?v=4",
    workos_user_id: "user_demo_efe"
  })

{:ok, _membership} =
  Accounts.create_membership(%{organization_id: org.id, user_id: efe.id, role: "owner"})

{:ok, human_actor} =
  Actors.create_actor(%{
    organization_id: org.id,
    type: "human",
    display_name: "Efe",
    trust_level: "trusted",
    external_ref: "workos:user_demo_efe",
    created_by_user_id: efe.id
  })

{:ok, agent_actor} =
  Actors.create_actor(%{
    organization_id: org.id,
    type: "agent",
    display_name: "codex-prod-17",
    trust_level: "trusted",
    external_ref: "agent:codex-prod-17",
    signing_key_ref: "kms://demo/codex-prod-17",
    created_by_user_id: efe.id
  })

{:ok, merge_actor} =
  Actors.create_actor(%{
    organization_id: org.id,
    type: "system",
    display_name: "Vela Merge",
    trust_level: "trusted",
    external_ref: "system:vela-merge"
  })

{:ok, security_actor} =
  Actors.create_actor(%{
    organization_id: org.id,
    type: "security_scanner",
    display_name: "Vela Security",
    trust_level: "trusted",
    external_ref: "scanner:vela-security"
  })

{:ok, _identity} =
  Agents.create_agent_identity(%{
    actor_id: agent_actor.id,
    issuer_organization_id: org.id,
    did: "did:vela:agent:codex-prod-17",
    public_key: "ed25519:demo-public-key-codex-prod-17",
    trust_score: 86,
    status: "active"
  })

{:ok, policy} =
  Agents.create_agent_policy(%{
    organization_id: org.id,
    actor_id: agent_actor.id,
    name: "Frontend and policy-safe agent scope",
    allowed_repos: ["sardis", "vela"],
    allowed_branches: ["feature/*", "agent/*"],
    allowed_paths: ["/apps", "/components", "/policies", "/test"],
    forbidden_paths: ["/billing", "/auth/secrets", "/infra/prod"],
    max_pr_size: 1200,
    requires_human_approval: true,
    can_merge: false,
    can_deploy: false,
    status: "active"
  })

{:ok, sardis_repo} =
  Forge.create_repository(%{
    organization_id: org.id,
    name: "sardis",
    slug: "sardis",
    visibility: "private",
    default_branch: "main",
    description: "Governed payment control plane for AI agents.",
    repo_cell_id: "cell-us-east-1-demo",
    health_status: "healthy",
    risk_level: "medium"
  })

{:ok, vela_repo} =
  Forge.create_repository(%{
    organization_id: org.id,
    name: "vela",
    slug: "vela",
    visibility: "private",
    default_branch: "main",
    description: "AI-native forge for trusted software.",
    repo_cell_id: "cell-us-east-1-demo",
    health_status: "degraded",
    risk_level: "high"
  })

{:ok, sardis_main} =
  Forge.create_branch(%{
    repository_id: sardis_repo.id,
    name: "main",
    current_sha: "8f6c1a2e9d35b4a77c6eae9192b6d5d0b4f40a91",
    protected: true
  })

{:ok, _sardis_feature} =
  Forge.create_branch(%{
    repository_id: sardis_repo.id,
    name: "agent/spending-policy-enforcement",
    current_sha: "c7a1e42d923c53dd8e338f4b887a7a73ed09ab54",
    protected: false
  })

{:ok, _vela_main} =
  Forge.create_branch(%{
    repository_id: vela_repo.id,
    name: "main",
    current_sha: "45f2c3e5d36e466a65c7698872df0462f621b988",
    protected: true
  })

{:ok, _vela_feature} =
  Forge.create_branch(%{
    repository_id: vela_repo.id,
    name: "agent/auth-token-validation",
    current_sha: "4f2dd27765cf87b1bc9d31533ae4dd270b9920fd",
    protected: false
  })

{:ok, session} =
  Agents.create_agent_session(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    agent_actor_id: agent_actor.id,
    human_supervisor_id: efe.id,
    branch_id: sardis_main.id,
    task_intent: "Add fail-closed spending policy enforcement before delegated agent payments.",
    prompt_hash: "sha256:9c2d4a0d9f7c6d7a6f0e2a4b2d7c9a2e",
    model: "gpt-5.3-codex",
    toolchain: %{"editor" => "Codex", "runner" => "self-hosted-demo"},
    status: "completed",
    started_at: DateTime.add(now, -7200, :second),
    ended_at: DateTime.add(now, -5400, :second)
  })

{:ok, ship_pr} =
  Forge.create_pull_request(%{
    repository_id: sardis_repo.id,
    author_actor_id: agent_actor.id,
    title: "Add agent spending policy enforcement",
    description:
      "Introduces path-scoped policy checks before delegated spending actions execute.",
    source_branch: "agent/spending-policy-enforcement",
    target_branch: "main",
    head_sha: "c7a1e42d923c53dd8e338f4b887a7a73ed09ab54",
    base_sha: "8f6c1a2e9d35b4a77c6eae9192b6d5d0b4f40a91",
    status: "ready_for_review",
    intent: "Enforce path-scoped spending policies before agent-created payment actions execute.",
    behavioral_summary:
      "Adds a fail-closed policy check before delegated spending actions and records policy decisions as evidence events.",
    risk_level: "medium"
  })

{:ok, blocked_pr} =
  Forge.create_pull_request(%{
    repository_id: vela_repo.id,
    author_actor_id: agent_actor.id,
    title: "Refactor auth token validation",
    description: "Attempts to consolidate token refresh and billing permission checks.",
    source_branch: "agent/auth-token-validation",
    target_branch: "main",
    head_sha: "4f2dd27765cf87b1bc9d31533ae4dd270b9920fd",
    base_sha: "45f2c3e5d36e466a65c7698872df0462f621b988",
    status: "blocked",
    intent: "Simplify auth token validation across API middleware.",
    behavioral_summary:
      "Refactors auth refresh behavior but also changes billing permission scope, creating an unsafe review boundary.",
    risk_level: "high"
  })

{:ok, _review} =
  Forge.create_review(%{
    pull_request_id: ship_pr.id,
    actor_id: human_actor.id,
    status: "approve",
    summary: "Policy boundary is explicit. Ship after preserving the negative-path test evidence."
  })

{:ok, _issue} =
  Forge.create_issue(%{
    repository_id: vela_repo.id,
    author_actor_id: human_actor.id,
    title: "Define WorkOS callback hardening before production auth",
    body: "Phase 0 keeps WorkOS as an interface boundary; Phase 1 must lock callback validation.",
    status: "open",
    priority: "high",
    labels: ["auth", "phase-1"]
  })

{:ok, change} =
  Forge.create_change(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    author_actor_id: agent_actor.id,
    title: "Pre-execution payment policy gate",
    description: "Tracked Change record backing the agent-authored policy enforcement PR.",
    source_ref: ship_pr.source_branch,
    target_ref: ship_pr.target_branch,
    head_sha: ship_pr.head_sha,
    base_sha: ship_pr.base_sha,
    status: "approved",
    risk_level: "medium",
    metadata: %{"pull_request_id" => ship_pr.id}
  })

{:ok, ship_analysis} =
  Maestro.create_analysis_run(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    pull_request_id: ship_pr.id,
    commit_sha: ship_pr.head_sha,
    status: "completed",
    started_at: DateTime.add(now, -5000, :second),
    completed_at: DateTime.add(now, -4700, :second),
    summary: "Policy enforcement change is bounded and supported by test evidence."
  })

ship_score_attrs =
  Maestro.compute_readiness_score(%{
    analysis_run_id: ship_analysis.id,
    pull_request_id: ship_pr.id,
    behavioral_score: 87,
    correctness_score: 81,
    security_score: 76,
    performance_score: 84,
    ux_score: 90,
    test_evidence_score: 80,
    rollback_score: 74,
    agent_provenance_score: 78,
    confidence: "high",
    explanation:
      "The virtual merge preserves the tested tree and the policy gate fails closed for delegated spending actions.",
    blocking_findings: [],
    required_actions: ["Keep the negative-path policy test attached to the merge candidate."],
    repo_profile: :payments_or_auth
  })
  |> Map.put(:overall_score, 82)

{:ok, ship_score} = Maestro.create_launch_readiness_score(ship_score_attrs)

trust_readiness =
  Maestro.compute_readiness(%{
    confidence: "high",
    dimensions: %{
      "repository_trust" => 86,
      "change_risk" => 78,
      "test_evidence" => 80,
      "security" => 76,
      "performance" => 84,
      "agent_provenance" => 78,
      "launch_readiness" => 82
    }
  })

{:ok, _readiness_score} =
  Maestro.create_readiness_score(
    trust_readiness
    |> Map.merge(%{
      organization_id: org.id,
      repository_id: sardis_repo.id,
      change_id: change.id,
      analysis_run_id: ship_analysis.id,
      explanation:
        "Trust score combines repository health, bounded change risk, security, tests, performance, provenance, and launch readiness.",
      evidence_refs: []
    })
  )

{:ok, ship_candidate} =
  Merge.create_merge_candidate(%{
    repository_id: sardis_repo.id,
    pull_request_id: ship_pr.id,
    base_sha: ship_pr.base_sha,
    head_sha: ship_pr.head_sha,
    virtual_merge_sha: "9bb6fd1e29dd7d21a127f5b8986e20a2f6cfa732",
    virtual_merge_tree_hash: "tree:ship-demo-virtual",
    tested_tree_hash: "tree:ship-demo-tested",
    final_merge_tree_hash: "tree:ship-demo-tested",
    status: "ready",
    queue_position: 1,
    analysis_run_id: ship_analysis.id,
    policy_result: %{"verdict" => "allow", "mode" => "human-supervised"},
    rollback_plan: %{
      "strategy" => "revert-merge-commit",
      "estimated_time" => "under 5 minutes",
      "evidence_required" => ["merge.completed", "deployment.approved"]
    }
  })

{:ok, _ship_pr} =
  Forge.update_pull_request(ship_pr, %{
    readiness_score_id: ship_score.id,
    merge_candidate_id: ship_candidate.id
  })

{:ok, blocked_analysis} =
  Maestro.create_analysis_run(%{
    organization_id: org.id,
    repository_id: vela_repo.id,
    pull_request_id: blocked_pr.id,
    commit_sha: blocked_pr.head_sha,
    status: "completed",
    started_at: DateTime.add(now, -4300, :second),
    completed_at: DateTime.add(now, -4000, :second),
    summary: "Auth and billing scope changed together without sufficient negative-path coverage."
  })

blocked_score_attrs =
  Maestro.compute_readiness_score(%{
    analysis_run_id: blocked_analysis.id,
    pull_request_id: blocked_pr.id,
    behavioral_score: 62,
    correctness_score: 57,
    security_score: 54,
    performance_score: 82,
    ux_score: 68,
    test_evidence_score: 38,
    rollback_score: 61,
    agent_provenance_score: 42,
    confidence: "medium",
    explanation:
      "The change modifies auth and billing permission boundaries together, lacks negative-path tests, and exceeds the agent path scope.",
    blocking_findings: [
      %{"severity" => "high", "message" => "missing negative-path tests"},
      %{"severity" => "critical", "message" => "modifies auth and billing permissions together"},
      %{"severity" => "high", "message" => "agent exceeded path scope"},
      %{"severity" => "high", "message" => "merge simulation failed"}
    ],
    required_actions: [
      "Split auth validation from billing permission changes.",
      "Add failed refresh and revoked token tests.",
      "Move production auth files outside the agent scope."
    ],
    repo_profile: :payments_or_auth
  })
  |> Map.put(:overall_score, 54)

{:ok, blocked_score} = Maestro.create_launch_readiness_score(blocked_score_attrs)

{:ok, blocked_candidate} =
  Merge.create_merge_candidate(%{
    repository_id: vela_repo.id,
    pull_request_id: blocked_pr.id,
    base_sha: blocked_pr.base_sha,
    head_sha: blocked_pr.head_sha,
    virtual_merge_sha: nil,
    virtual_merge_tree_hash: "tree:block-demo-virtual",
    tested_tree_hash: "tree:block-demo-tested",
    final_merge_tree_hash: nil,
    status: "blocked",
    queue_position: nil,
    analysis_run_id: blocked_analysis.id,
    policy_result: %{
      "verdict" => "block",
      "reasons" => [
        "agent path violation",
        "missing negative-path tests",
        "merge simulation failed"
      ]
    },
    rollback_plan: %{
      "status" => "not-generated",
      "reason" => "candidate blocked before merge readiness"
    }
  })

{:ok, _blocked_pr} =
  Forge.update_pull_request(blocked_pr, %{
    readiness_score_id: blocked_score.id,
    merge_candidate_id: blocked_candidate.id
  })

{:ok, runner} =
  Pipelines.create_runner(%{
    organization_id: org.id,
    name: "sardis-labs-mac-mini",
    type: "self_hosted",
    labels: ["macos", "docker", "playwright"],
    status: "online",
    last_seen_at: now
  })

{:ok, pipeline_run} =
  Pipelines.create_pipeline_run(%{
    repository_id: sardis_repo.id,
    pull_request_id: ship_pr.id,
    commit_sha: ship_pr.head_sha,
    status: "completed",
    score_impact: 7,
    started_at: DateTime.add(now, -5200, :second),
    completed_at: DateTime.add(now, -5050, :second)
  })

{:ok, _job} =
  Pipelines.create_pipeline_job(%{
    pipeline_run_id: pipeline_run.id,
    name: "policy and negative-path tests",
    command: "mix test test/vela/policy_test.exs",
    sandbox_config: %{"runner" => runner.name},
    logs_ref: "s3://vela-demo-artifacts/logs/policy-tests.txt",
    artifacts_ref: "s3://vela-demo-artifacts/artifacts/policy-tests.json",
    status: "completed"
  })

{:ok, _trust_signal} =
  Forge.create_repository_trust_signal(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    source: "seed",
    signal_type: "protected_branch",
    score: 90,
    confidence: "high",
    payload: %{"branch" => "main", "required_reviews" => 1}
  })

{:ok, integration} =
  Vela.Integrations.create_integration(%{
    organization_id: org.id,
    provider: "vercel",
    name: "Sardis Vercel",
    status: "active",
    config: %{"team" => "sardis-labs"},
    token_ciphertext: "kms://demo/vercel-token",
    external_ref: "vercel:team_demo"
  })

{:ok, environment} =
  Vela.Integrations.create_environment(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    name: "production",
    type: "production",
    status: "active",
    metadata: %{"domain" => "sardis.sh"}
  })

{:ok, _service_connection} =
  Vela.Integrations.create_service_connection(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    integration_id: integration.id,
    environment_id: environment.id,
    service_name: "sardis-api",
    service_type: "deployment",
    status: "active",
    external_ref: "vercel:project_sardis_api"
  })

{:ok, _release_candidate} =
  Vela.Releases.create_release_candidate(%{
    organization_id: org.id,
    repository_id: sardis_repo.id,
    merge_candidate_id: ship_candidate.id,
    created_by_actor_id: human_actor.id,
    version: "2026.05.05-demo",
    environment: "production",
    status: "ready",
    artifact_ref: "s3://vela-demo-artifacts/releases/2026.05.05-demo.json",
    rollback_plan: %{"strategy" => "revert-merge-commit"}
  })

for {event_type, actor, resource_type, resource_id, payload} <- [
      {"repo.created", human_actor, "repository", sardis_repo.id,
       %{"name" => sardis_repo.name, "visibility" => sardis_repo.visibility}},
      {"repo.created", human_actor, "repository", vela_repo.id,
       %{"name" => vela_repo.name, "visibility" => vela_repo.visibility}},
      {"integration.event_received", merge_actor, "integration", integration.id,
       %{"provider" => integration.provider, "status" => integration.status}}
    ] do
  {:ok, _event} =
    Evidence.append_event(%{
      organization_id: org.id,
      actor_id: actor.id,
      event_type: event_type,
      resource_type: resource_type,
      resource_id: resource_id,
      payload: payload
    })
end

for {event_type, actor, repo, resource_type, resource_id, payload} <- [
      {"agent.session.started", agent_actor, sardis_repo, "agent_session", session.id,
       %{"task_intent" => session.task_intent, "model" => session.model}},
      {"push.received", agent_actor, sardis_repo, "repository", sardis_repo.id,
       %{"branch" => "agent/spending-policy-enforcement", "head_sha" => ship_pr.head_sha}},
      {"pr.opened", agent_actor, sardis_repo, "pull_request", ship_pr.id,
       %{"title" => ship_pr.title, "source_branch" => ship_pr.source_branch}},
      {"analysis.started", merge_actor, sardis_repo, "analysis_run", ship_analysis.id,
       %{"commit_sha" => ship_pr.head_sha}},
      {"score.computed", merge_actor, sardis_repo, "launch_readiness_score", ship_score.id,
       %{"overall_score" => 82, "verdict" => "ship", "confidence" => "high"}},
      {"merge.simulated", merge_actor, sardis_repo, "merge_candidate", ship_candidate.id,
       %{
         "tested_tree_hash" => ship_candidate.tested_tree_hash,
         "final_merge_tree_hash" => ship_candidate.final_merge_tree_hash
       }},
      {"policy.evaluated", security_actor, sardis_repo, "pull_request", ship_pr.id,
       %{"verdict" => "allow", "policy_id" => policy.id}},
      {"merge.blocked", security_actor, vela_repo, "pull_request", blocked_pr.id,
       %{
         "verdict" => "block",
         "score" => 54,
         "reasons" => blocked_candidate.policy_result["reasons"]
       }}
    ] do
  {:ok, _event} =
    Evidence.append_event(%{
      organization_id: org.id,
      repository_id: repo.id,
      actor_id: actor.id,
      event_type: event_type,
      resource_type: resource_type,
      resource_id: resource_id,
      payload: payload
    })
end

{:ok, org_chain} = Evidence.verify_chain(org.id)
{:ok, sardis_chain} = Evidence.verify_chain(org.id, sardis_repo.id)
{:ok, vela_chain} = Evidence.verify_chain(org.id, vela_repo.id)

IO.puts(
  "Seeded Vela Phase 0 demo workspace for #{org.name}. Evidence chains: org=#{org_chain.count}, sardis=#{sardis_chain.count}, vela=#{vela_chain.count}."
)
