# Vela 150-Commit Transformation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Vela from a credible Phase 0 control-plane demo into a clean, incrementally shippable trusted forge with sharp boundaries, real repository workflows, stronger evidence semantics, and public OSS-quality surfaces.

**Architecture:** Keep Phoenix/Postgres as the canonical control plane for now. Split overloaded HTTP and LiveView modules into small boundary modules before adding more product scope. Add real integrations in the order that reduces trust theater: repository import and metadata first, diff/readiness/merge invariants second, runner/evidence/export third, sidecars last.

**Tech Stack:** Elixir/Phoenix LiveView, Ecto/Postgres, Oban, Req, Tailwind, OpenAPI, JSON Schema, future Rust/Python service contracts.

---

## Current Read

Vela is stronger than a normal scaffold: it has a real Phoenix app, a broad Ecto domain model, WorkOS session auth boundary, webhook signature verification, idempotent job mutations, Oban workers, hash-chained evidence events, GitHub import/comment/sync work, API docs, and 94 passing tests.

The weak part is not effort. The weak part is shape. The repo mixes product truth, demo copy, future-service promises, and production-critical semantics in the same surfaces. The two biggest files show the main pattern: `apps/web/lib/vela_web/controllers/api/v1/foundation_controller.ex` has endpoint logic, serialization, idempotency, evidence/outbox writes, GitHub publishing, pagination, validation, tenant checks, and job orchestration in one controller; `apps/web/lib/vela_web/live/app_live.ex` has almost the entire app shell, all pages, route loading, query calls, demo copy, and UI helpers in one LiveView.

## What Is Wrong Or Missing

1. **Controller boundary is too broad.** The API controller is doing orchestration and infrastructure work that should live in API support modules and domain services.
2. **The LiveView is a product monolith.** It is hard to evolve the repo view, PR cockpit, launch cockpit, evidence ledger, and settings independently.
3. **Public route posture is still demo-biased.** Some read endpoints are intentionally public for Phase 0. That is acceptable as a demo decision but must become a named mode, not an accidental product default.
4. **Evidence is promising but not yet operationally complete.** Hash chaining exists, but export, verification, replay diagnostics, chain repair policy, and tamper alarms are not yet first-class.
5. **Merge queue is metadata-first.** Queueing is gated on review/readiness, but no real tree equivalence, base invalidation, signed merge execution, branch protection enforcement, or final merge adapter exists.
6. **Repository experience is shallow.** GitHub metadata import has started, but code browsing, real diffs, file-level risk, comments anchored to diff hunks, branch protection UI, and issue flows are absent.
7. **Agent trust is modeled but not yet felt.** Agent identities and signatures exist, but tokens, leases, scoped actions, event signing requirements, key rotation, and conflict detection are still roadmap items.
8. **Sidecar directories are mostly contracts.** `services/*` communicates the desired architecture but can inflate perceived implementation unless status stays explicit.
9. **SDK and UI packages are placeholders.** `packages/sdk-js`, `packages/sdk-python`, and `packages/ui` do not yet create external developer value.
10. **Docs are good but optimistic.** The docs mostly say the right things, but need stronger status taxonomy: implemented, modeled, mocked, contract-only, planned.
11. **No CI visible in the repo map.** Local `scripts/check.sh` is good; GitHub Actions should enforce it.
12. **No ADR for recent product pivots.** Merge queue, GitHub adapter, evidence hardening, and public/private API posture need decisions.
13. **Tests exist but are concentrated around backend contracts.** UI regression, OpenAPI contract tests, evidence-chain property tests, and worker retry/idempotency tests should deepen.
14. **Seed data leaks too much demo framing into product pages.** Seeded Sardis demo is useful, but demo fixtures should be isolated and clearly not product defaults.
15. **The core narrative is strong but the product has not yet earned all claims.** "GitHub stores code. Vela proves whether code can be trusted" is good, but proof needs real diff, policy, runner, merge, and evidence verification loops.

## File Boundary Target

- `apps/web/lib/vela_web/controllers/api/v1/foundation_controller.ex`: shrink to HTTP action dispatch and response plumbing only.
- `apps/web/lib/vela_web/controllers/api/v1/response.ex`: API pagination, serialization, validation and common errors.
- `apps/web/lib/vela_web/controllers/api/v1/mutation_audit.ex`: evidence/outbox writes for accepted mutations.
- `apps/web/lib/vela_web/controllers/api/v1/repo_actions.ex`: repository import/sync orchestration.
- `apps/web/lib/vela_web/controllers/api/v1/pull_request_actions.ex`: PR comment and merge queue orchestration.
- `apps/web/lib/vela_web/live/app_live.ex`: shrink to shell and route dispatch.
- `apps/web/lib/vela_web/live/repository_live.ex`, `pull_request_live.ex`, `agent_live.ex`, `launch_live.ex`, `evidence_live.ex`, `settings_live.ex`: split product surfaces when the current LiveView becomes the blocker.
- `apps/web/lib/vela/evidence/verifier.ex`: chain verification.
- `apps/web/lib/vela/merge/gates.ex`: review/readiness/base/tree gates.
- `apps/web/lib/vela/git/diff_model.ex`: normalized provider diff representation.
- `docs/status.md`: truth table for implemented/mocked/contract-only/planned.

## 150 Atomic Commits

### Tranche 1: Repo Truth And Guardrails

1. `docs: add implementation status taxonomy` - Create `docs/status.md` with implemented, modeled, mocked, contract-only, planned categories.
2. `docs: add 150-commit transformation plan` - Land this plan as the durable roadmap.
3. `ci: add Phoenix check workflow` - Add GitHub Actions running `./scripts/check.sh`.
4. `docs: document local verification contract` - Clarify setup/check/test commands and database assumptions.
5. `docs: add architecture risk register` - Track trust-theater risks and current mitigations.
6. `docs: add ADR for demo versus production modes` - Make public read endpoints an explicit Phase 0 demo mode.
7. `docs: add ADR for API controller decomposition` - Document the boundary before moving code.
8. `docs: align README with status taxonomy` - Replace broad Phase 0 prose with exact current-state bullets.
9. `docs: label service directories contract-only` - Add status banners to each `services/*/README.md`.
10. `docs: label package placeholders honestly` - Mark SDK/UI packages as planned or minimal.

### Tranche 2: API Controller Decomposition

11. `refactor(api): extract response serialization helpers` - Move pagination, schema serialization, changeset errors, and common JSON errors out of `FoundationController`.
12. `test(api): cover response helper serialization` - Add unit tests for not-loaded associations, type naming, pagination limits, and validation errors.
13. `refactor(api): extract idempotent mutation helper` - Move `Idempotency.run/4` wrapper into API support.
14. `test(api): cover idempotent mutation response paths` - Unit-test success, replay, and conflict envelopes.
15. `refactor(api): extract mutation audit writer` - Move evidence/outbox writes for queued jobs and PR comments.
16. `test(api): cover mutation audit atomic writes` - Assert evidence and outbox are written together.
17. `refactor(api): extract repo import action module` - Move GitHub placeholder upsert and import job orchestration.
18. `test(api): cover repo import action directly` - Exercise unsupported provider, placeholder reuse, job evidence.
19. `refactor(api): extract PR comment action module` - Move local review creation and GitHub publishing decision.
20. `test(api): cover PR comment action directly` - Cover local-only and publish-to-GitHub behavior with transport stub.
21. `refactor(api): extract PR merge queue action module` - Move queue gate orchestration and audit write.
22. `test(api): cover PR merge action directly` - Cover missing approval, blocking review, readiness, and success.
23. `refactor(api): extract webhook ingestion action` - Move context validation and integration event recording.
24. `test(api): cover webhook tenant validation action` - Verify org/repo/actor mismatch blocks evidence writes.
25. `refactor(api): split read collection queries` - Move collection query functions into `VelaWeb.Api.V1.ReadModels`.
26. `test(api): cover collection pagination consistency` - Ensure all collection endpoints use the same limit semantics.
27. `refactor(api): make FoundationController thin` - Keep actions, `with` chains, and status mapping only.
28. `test(api): preserve full API surface after split` - Re-run existing API controller tests and add route smoke assertions.
29. `docs(api): document internal API support modules` - Add a short architecture note.
30. `chore(api): enforce controller size guard in check script` - Add a lightweight line-count warning or documented threshold.

### Tranche 3: Domain Service Boundaries

31. `refactor(forge): split repository queries` - Create `Vela.Forge.Repositories`.
32. `refactor(forge): split pull request queries` - Create `Vela.Forge.PullRequests`.
33. `refactor(forge): split review operations` - Create `Vela.Forge.Reviews`.
34. `refactor(forge): split trust signal operations` - Create `Vela.Forge.TrustSignals`.
35. `test(forge): cover repository tenant queries` - Lock org scoping.
36. `test(forge): cover pull request route lookup` - Lock preload expectations.
37. `refactor(merge): extract gates module` - Move review/readiness gate code into `Vela.Merge.Gates`.
38. `test(merge): cover gates in isolation` - Cover blocking review and missing readiness.
39. `refactor(maestro): extract scoring profiles` - Separate weights and profile lookup.
40. `test(maestro): cover profile scoring edge cases` - Add low confidence and missing dimension tests.
41. `refactor(jobs): split job constructors by domain` - Keep `Vela.Jobs` facade.
42. `test(jobs): cover job argument contracts` - Ensure job args stay stable.
43. `refactor(webhooks): split signature providers` - Create provider-specific verifier modules.
44. `test(webhooks): cover provider verifier matrix` - Lock GitHub, Stripe, Svix, generic HMAC.
45. `docs: update backend module map` - Keep `docs/architecture.md` aligned with splits.

### Tranche 4: Evidence Ledger Hardening

46. `feat(evidence): add chain verifier` - Verify per-repository and org-level chains.
47. `test(evidence): detect broken hash chain` - Tamper with payload and assert failure.
48. `test(evidence): verify empty and single-event chains` - Cover boundary cases.
49. `feat(evidence): add verification API endpoint` - Expose chain verification summary.
50. `test(api): cover evidence verification endpoint` - Assert healthy and broken responses.
51. `feat(evidence): add export cursor` - Paginated evidence export with stable ordering.
52. `test(evidence): cover export cursor stability` - Ensure no skip/duplicate on same timestamp.
53. `feat(evidence): add event type registry` - Centralize allowed event names.
54. `test(evidence): reject unknown critical event types` - Keep exploratory events allowed only under a clear namespace.
55. `feat(evidence): require actor on critical events` - Enforce non-null actor for mutating product events.
56. `test(evidence): cover critical actor requirement` - Ensure system events have explicit system actor path.
57. `feat(evidence): add tamper alarm model` - Persist failed verification incidents.
58. `test(evidence): cover tamper alarm creation` - Verify no duplicate alarm spam.
59. `docs(evidence): document verification and export` - Include operator commands.
60. `chore(seeds): seed evidence verifier demo state` - Add healthy chain examples only.

### Tranche 5: Auth, RBAC, And Tenant Posture

61. `feat(auth): add explicit demo mode config` - Replace implicit public read posture with config.
62. `test(auth): public reads disabled outside demo` - Verify protected reads under production-like config.
63. `feat(rbac): add API permission checks` - Gate repo mutations by role.
64. `test(rbac): cover repo mutation roles` - Owner/admin/maintainer allowed, observer denied.
65. `feat(rbac): gate PR comments and merge queue` - Require reviewer/maintainer roles as appropriate.
66. `test(rbac): cover PR mutation roles` - Cover allowed and denied paths.
67. `feat(auth): add API token model stub` - Model service tokens without issuing secrets yet.
68. `test(auth): cover token changeset constraints` - Validate org, actor, scopes, expiry.
69. `feat(auth): add signed token hashing utility` - Store hashes, never raw token.
70. `test(auth): cover token hash verification` - Ensure constant-time verify.
71. `docs(security): document demo mode and auth posture` - Be explicit for OSS readers.
72. `docs(api): mark auth requirements per endpoint` - Table with demo/prod behavior.

### Tranche 6: GitHub Integration Depth

73. `feat(github): import repository branches` - Persist default and protected branch metadata.
74. `test(github): cover branch import mapping` - Use Req transport stub.
75. `feat(github): import PR changed files` - Normalize file path, status, additions/deletions.
76. `test(github): cover changed-file mapping` - Include rename/deletion cases.
77. `feat(git): add normalized diff model` - Provider-agnostic diff records.
78. `test(git): cover diff model validation` - Validate path, sha, patch presence rules.
79. `feat(github): import PR review state` - Sync approvals/request-changes from GitHub.
80. `test(github): cover review sync mapping` - Ensure latest review state is preserved.
81. `feat(github): import check runs` - Store CI/check metadata as readiness input.
82. `test(github): cover check run mapping` - Map success/failure/skipped consistently.
83. `feat(sync): make PR sync idempotent by provider ids` - Avoid duplicate local rows.
84. `test(sync): cover repeated PR sync` - Assert counts remain stable.
85. `docs(api): document GitHub sync depth` - Explain which remote fields are trusted.

### Tranche 7: Merge Queue Correctness

86. `feat(merge): add branch protection model checks` - Include required approvals/checks.
87. `test(merge): cover branch protection gates` - Lock denial reasons.
88. `feat(merge): add base sha freshness gate` - Block stale base before queue.
89. `test(merge): cover stale base denial` - Simulate changed default branch.
90. `feat(merge): add tree equivalence state model` - Separate virtual, tested, final tree invariants.
91. `test(merge): cover tree equivalence transitions` - Block final mismatch.
92. `feat(merge): add queue position model` - Deterministic ordering per repo/branch.
93. `test(merge): cover queue ordering` - Ensure stable ordering and no duplicates.
94. `feat(merge): add queue dequeue/cancel action` - Allow maintainers to cancel.
95. `test(api): cover merge cancel endpoint` - Include evidence/outbox write.
96. `feat(merge): add merge execution adapter behavior` - Contract for future GitHub/direct Git execution.
97. `test(merge): cover adapter contract with fake` - Verify success/failure shape.
98. `docs(merge): update merge queue invariants` - Document every blocking reason.
99. `docs(api): document merge cancel and gate errors` - Keep API docs current.
100. `chore(seeds): seed stale and blocked queue examples` - Make UI show real gate variety.

### Tranche 8: Maestro And Readiness

101. `feat(readiness): persist evidence inputs` - Link scores to check runs, diffs, reviews.
102. `test(readiness): cover score input lineage` - Ensure score can be reconstructed.
103. `feat(readiness): explain score dimensions` - Store dimension-level explanations.
104. `test(readiness): cover explanation validation` - Require useful text for non-ship verdicts.
105. `feat(maestro): add analysis callback endpoint` - Accept external service results.
106. `test(api): verify signed analysis callbacks` - Reuse webhook signature posture.
107. `feat(maestro): add deterministic local analyzers` - File risk, test coverage hints, sensitive paths.
108. `test(maestro): cover file-risk analyzer` - Include security/payment/config paths.
109. `feat(maestro): add score recalculation job` - Queue after PR sync.
110. `test(jobs): cover score recalculation worker` - Assert evidence written.
111. `docs(maestro): separate deterministic and LLM analysis` - Prevent AI magic framing.
112. `docs(openapi): document analysis callback` - Keep OpenAPI in sync.

### Tranche 9: UI Decomposition And Product Quality

113. `refactor(ui): extract app shell components` - Move sidebar/header/nav helpers.
114. `test(live): preserve navigation render` - Keep existing LiveView tests green.
115. `refactor(ui): extract repository page module` - Move repo rendering helpers.
116. `test(live): cover repository page states` - Empty PRs, multiple PRs, risky repo.
117. `refactor(ui): extract pull request cockpit module` - Move PR page rendering.
118. `test(live): cover PR cockpit risk states` - Ship/wait/block variants.
119. `refactor(ui): extract evidence page module` - Move evidence rendering.
120. `test(live): cover evidence empty and populated states` - Avoid nil assumptions.
121. `feat(ui): add repository import form` - Real form for GitHub owner/repo import.
122. `test(live): cover repository import form` - Validate input and redirect/flash.
123. `feat(ui): add PR comment form` - Local comment and optional publish.
124. `test(live): cover PR comment form` - Assert review/evidence write.
125. `feat(ui): add merge queue button with gate errors` - Surface exact denial reasons.
126. `test(live): cover merge queue button states` - Approved, blocked, stale, queued.
127. `feat(ui): add diff file list surface` - Render imported changed files.
128. `test(live): cover changed file rendering` - Renames/deletions/security markers.
129. `feat(ui): add evidence verifier status` - Show chain health per repo.
130. `test(live): cover evidence verifier status` - Healthy/tampered/unknown.

### Tranche 10: SDK, Protocol, And External Credibility

131. `feat(protocol): define event envelope versioning` - Add schemaVersion/version policy.
132. `test(protocol): validate event schemas in mix test` - Wire JSON schema check task.
133. `feat(sdk-js): add minimal typed client` - List repos, import repo, sync PR.
134. `test(sdk-js): add client serialization tests` - Use node test or documented command.
135. `feat(sdk-python): add minimal client skeleton` - Same small endpoint set.
136. `test(sdk-python): add client unit tests` - Use stdlib unittest or pytest only if already justified.
137. `docs(sdk): add JS quickstart` - Copy-pasteable minimal example.
138. `docs(sdk): add Python quickstart` - Copy-pasteable minimal example.
139. `docs(protocol): add webhook event examples` - Include signed event examples.
140. `docs: add contribution guide` - OSS-friendly setup, tests, issue labels.

### Tranche 11: Ops, Deployment, And Release Readiness

141. `feat(ops): add readiness endpoint dependency checks` - Database, Oban, config posture.
142. `test(ops): cover readiness failure modes` - DB down is hard to test, config checks are not.
143. `feat(ops): add structured audit log export task` - Mix task for evidence/export.
144. `test(ops): cover audit export task` - Validate JSONL output shape.
145. `docs(deploy): add single-node production runbook` - Phoenix/Postgres/Oban/object storage.
146. `docs(deploy): add secret inventory` - Required env vars and rotation notes.
147. `docs(security): add threat model` - Replay, tenant bypass, merge spoofing, secret leak, evidence tamper.
148. `docs: add public roadmap with honest status` - Now/Next/Later with no inflated claims.
149. `chore: run full precommit and fix drift` - `mix precommit` clean.
150. `release: tag phase-1-private-forge-baseline` - Only after code, docs, and tests match the taxonomy.

## First Execution Slice

- [x] Inspect repo, stack, git status, tests, docs, and module size.
- [x] Run `mix test` from `apps/web`; expected and observed: 94 tests, 0 failures.
- [x] Commit this transformation plan.
- [x] Implement Commit 11: extract API response serialization helpers.
- [x] Implement Commit 12: add direct response helper tests.
- [x] Implement Commit 13: extract idempotent mutation helper.
- [x] Implement Commit 14: add direct idempotent mutation response tests.
- [x] Implement Commit 15: extract mutation audit writer.
- [x] Implement Commit 16: add direct mutation audit write tests.
- [x] Implement Commit 17: extract repository import actions.
- [x] Implement Commit 18: add direct repository import action tests.
- [x] Implement Commit 19: extract pull request comment action.
- [x] Implement Commit 20: add direct pull request comment action tests.
- [x] Run focused API tests after each extraction.
- [x] Run full `./scripts/check.sh`; expected and observed: format, warnings-as-errors compile, full test suite passing.

## Current Execution Status

Completed commits from this plan:

- 2. `docs: add 150-commit transformation plan`
- 11. `refactor(api): extract response serialization helpers`
- 12. `test(api): cover response helper serialization`
- 13. `refactor(api): extract idempotent mutation helper`
- 14. `test(api): cover idempotent mutation response paths`
- 15. `refactor(api): extract mutation audit writer`
- 16. `test(api): cover mutation audit atomic writes`
- 17. `refactor(api): extract repo import action module`
- 18. `test(api): cover repo import action directly`
- 19. `refactor(api): extract PR comment action module`
- 20. `test(api): cover PR comment action directly`

Next recommended commit:

- 21. `refactor(api): extract PR merge queue action module`

## Success Criteria

After this plan is executed, Vela should be easy to describe honestly:

- A Phoenix/Postgres trusted forge control plane with real GitHub metadata workflows.
- Evidence chains can be verified and exported.
- Merge queue decisions are explainable, reproducible, and blocked before unsafe execution.
- Agent identity and permissions are enforced in product workflows, not only modeled.
- The UI exposes useful repo/PR/evidence actions, not only demo cockpit copy.
- SDK/protocol packages give external developers a small but real integration path.
- Docs clearly separate implemented behavior from mocked or planned service boundaries.
