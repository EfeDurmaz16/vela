# API

The backend exposes a versioned JSON surface under `/api/v1`. Collections return:

```json
{
  "data": [],
  "pagination": { "limit": 25, "returned": 0 }
}
```

Phase 0 route surface and auth posture:

| Endpoint | Dev/test demo mode | Production default | Notes |
| --- | --- | --- | --- |
| `GET /api/v1/orgs` | Demo read | Disabled without demo mode | Returns `demo_mode_required` when `:api, demo_mode?: false`. |
| `GET /api/v1/repos` | Demo read | Disabled without demo mode | Collection only. Per-repository reads are session protected. |
| `GET /api/v1/repos/:id/trust` | Demo read | Disabled without demo mode | Trust signal collection for a repository id. |
| `GET /api/v1/changes` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/changes/:id/readiness` | Demo read | Disabled without demo mode | Readiness rows for a change id. |
| `GET /api/v1/pull-requests` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/agents` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/agents/:id/sessions` | Demo read | Disabled without demo mode | Agent session collection. |
| `GET /api/v1/agents/:id/policies` | Demo read | Disabled without demo mode | Agent policy collection. |
| `GET /api/v1/analysis-runs` | Demo read | Disabled without demo mode | Collection endpoint. |
| `POST /api/v1/analysis-runs/:id/callback` | Signed analysis callback | Signed analysis callback | Uses `analysis` webhook secret; accepts `completed`, `failed`, `cancelled`. |
| `GET /api/v1/readiness-scores` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/merge-candidates` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/releases` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/evidence-events` | Demo read | Disabled without demo mode | Recent evidence events. |
| `GET /api/v1/evidence-events/verify?organization_id=:organization_id[&repository_id=:repository_id]` | Demo read | Disabled without demo mode | Chain verification summary. |
| `GET /api/v1/integrations` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/service-connections` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/environments` | Demo read | Disabled without demo mode | Collection endpoint. |
| `GET /api/v1/auth/workos/login` | Public auth bootstrap | Public auth bootstrap | Returns a server-generated WorkOS authorization URL. |
| `GET /api/v1/auth/workos/callback` | Public auth callback | Public auth callback | Exchanges WorkOS code and writes the signed Phoenix session. |
| `POST /api/v1/webhooks/:provider` | Signature verified | Signature verified | Route is unauthenticated; provider verifier gates trust. |
| `POST /api/v1/repos` | Session + RBAC | Session + RBAC | `owner`, `admin`, `maintainer`. |
| `GET /api/v1/repos/:id` | Session + tenant check | Session + tenant check | Authenticated per-repository read. |
| `PUT /api/v1/repos/:id` | Session + RBAC | Session + RBAC | `owner`, `admin`, `maintainer`. |
| `DELETE /api/v1/repos/:id` | Session + RBAC | Session + RBAC | `owner`, `admin`; maintainers cannot delete. |
| `POST /api/v1/repos/import` | Session + RBAC | Session + RBAC | Starts GitHub import placeholder/job. |
| `POST /api/v1/repos/:id/import` | Session + tenant check + RBAC | Session + tenant check + RBAC | Existing repository import job. |
| `GET /api/v1/repos/:id/readiness` | Session + tenant check | Session + tenant check | Authenticated repository readiness summary. |
| `POST /api/v1/repos/:id/sync-pull-request` | Session + tenant check + RBAC | Session + tenant check + RBAC | GitHub PR sync job. |
| `POST /api/v1/pull-requests/:id/comments` | Session + tenant check + RBAC | Session + tenant check + RBAC | `reviewer`, `maintainer`, `admin`, `owner`. |
| `POST /api/v1/pull-requests/:id/merge` | Session + tenant check + RBAC + merge gates | Session + tenant check + RBAC + merge gates | Maintainer-level merge queue plus approval/readiness gates. |
| `POST /api/v1/merge-candidates/:id/cancel` | Session + tenant check + RBAC | Session + tenant check + RBAC | Maintainer-level cancellation for queued candidates. |
| `POST /api/v1/merge-candidates/:id/simulate` | Session + tenant check | Session + tenant check | Simulation job route. |

Operational endpoints:

- `GET /health`
- `GET /ready`
- `GET /metrics`

Webhook events include `repo.push`, `pull_request.opened`, `pull_request.updated`, `analysis.completed`, `score.changed`, `merge.blocked`, `merge.completed` and `deployment.ready`. Provider webhook verification uses provider-native signatures when available: GitHub `x-hub-signature-256`, Stripe `stripe-signature`, WorkOS `workos-signature`, and Svix-style `svix-id`, `svix-timestamp`, `svix-signature`. Other providers continue to use HMAC-SHA256 over `timestamp.body` with `x-vela-timestamp` and `x-vela-signature` or equivalent `x-webhook-*` headers. Comparisons are constant-time. Timestamped signatures are rejected outside the configured replay window, and webhook actor/repository context must belong to the supplied organization before evidence is written.

WorkOS AuthKit is handled server-side: the login route returns a WorkOS authorization URL and the callback route exchanges the returned code with WorkOS before reconciling Vela user, organization, membership and human actor records. On successful callback, Vela stores a compact `vela_api_auth` identity reference in the signed Phoenix session cookie. Protected API routes rehydrate `current_user`, `current_organization`, `current_membership`, and `current_actor` from those IDs on each request; missing, deleted, or mismatched records return `401 {"error":{"code":"api_auth_required"}}`.

Analysis callbacks use the generic Vela HMAC signature format: `x-vela-timestamp` plus `x-vela-signature`, where the signature covers `timestamp.body`. Configure the secret under the `analysis` provider key. Unsigned or invalid callbacks return `401 {"error":{"code":"analysis_callback_verification_failed"}}`; invalid terminal statuses return `422 {"error":{"code":"analysis_callback_invalid"}}`.

Demo read routes require `config :vela, :api, demo_mode?: true`; when disabled they return `401 {"error":{"code":"demo_mode_required"}}`. Repository CRUD, GitHub import start, GitHub PR sync, PR comments, reviewed PR merge queueing, merge cancellation and mutating job routes require the session-backed API auth pipeline. Job mutation routes support `Idempotency-Key`: reusing the same key with the same request body replays the first response without enqueueing another job, while reusing the same key with a different request returns `409 {"error":{"code":"idempotency_key_reused"}}`. Accepted job mutations write a hash-chained evidence event and a pending outbox event in the same database transaction as the queued Oban job. GitHub PR sync imports PR metadata, seeds a merge candidate, creates an initial readiness score and writes evidence/outbox. PR comment creation writes local review state, evidence, outbox and can publish to GitHub via the issue comments REST endpoint when requested. PR merge queueing moves the local merge candidate to `queued` only after all merge gates pass, then writes `merge.queued` evidence/outbox. Merge cancellation moves a queued candidate to `cancelled`, clears its queue position, compacts the repository/branch queue and writes `merge.cancelled` evidence/outbox.

## Auth And Idempotency Examples

Protected API mutations use the signed Phoenix session established by the WorkOS
callback. Browser clients send the session cookie automatically. Scripted
clients should use a future tenant-scoped API token; raw token issuance is
modeled but not exposed in Phase 0.

GitHub repository import:

```bash
curl -sS "http://localhost:4000/api/v1/repos/import" \
  -H "content-type: application/json" \
  -H "idempotency-key: repo-import-sardis-vela-001" \
  -b "_vela_key=<signed-session-cookie>" \
  -d '{"owner":"sardis-labs","repo":"vela","provider":"github"}'
```

Accepted response:

```json
{
  "data": {
    "repository": {
      "id": "repo-id",
      "provider": "github",
      "full_name": "sardis-labs/vela",
      "import_status": "pending"
    },
    "job": {
      "id": 42,
      "kind": "repo_import",
      "status": "queued"
    }
  }
}
```

Reusing the same `Idempotency-Key` with the same body returns the first response.
Reusing the key with a different body returns:

```json
{
  "error": {
    "code": "idempotency_key_reused"
  }
}
```

Pull request sync uses the repository id in the path and the provider PR number
in the body:

```bash
curl -sS "http://localhost:4000/api/v1/repos/repo-id/sync-pull-request" \
  -H "content-type: application/json" \
  -H "idempotency-key: pr-sync-repo-id-17-001" \
  -b "_vela_key=<signed-session-cookie>" \
  -d '{"number":17}'
```

Merge gate failures use `422 {"error":{"code":"merge_gate_failed","reason":"..."}}`. Current reasons are `missing_approval`, `blocking_review`, `branch_protection_missing_approvals`, `branch_protection_missing_checks`, `stale_base_sha`, `missing_readiness`, `readiness_not_ship`, `missing_merge_candidate` and invalid transition strings. Merge cancel failures use `409 {"error":{"code":"merge_cancel_failed","reason":"not_cancellable","status":"..."}}` when the candidate is not currently `queued`.

## GitHub Sync Depth

Repository import trusts GitHub repository metadata for provider identity, display name, full name, visibility, default branch, HTML URL and branch list. Branch sync persists branch name, current commit SHA and GitHub's protected flag. Vela does not infer branch protection rules from this flag yet; detailed rule import belongs to a later provider-sync step.

Pull request sync trusts GitHub for PR provider identity, PR number, title/body, source and target branches, head/base SHAs, author login, HTML URL and draft/open/closed/merged state. The worker persists the PR by `(repository_id, provider, external_number)` and keeps provider ids unique so repeated syncs update the same local PR.

Changed-file sync stores a provider-neutral file record per PR path: path, previous path for renames, status, blob SHA, additions, deletions, total changes, optional patch body, blob URL and raw URL. The normalized diff model treats unknown provider statuses as `changed`, requires paths and non-negative counters, and only requires patch text for textual changed-file statuses. Deleted files and unchanged/binary-style records can omit patch bodies.

Review sync stores GitHub review id, author login, submitted timestamp, summary body and mapped state. GitHub `APPROVED` maps to `approve`, `CHANGES_REQUESTED` maps to `request_changes`, and `COMMENTED` maps to `comment`. Repeated syncs update the existing provider review row instead of creating duplicates.

Check-run sync stores GitHub check id, name, status, conclusion, details URL and start/completion timestamps for the PR head SHA. Conclusions such as `success`, `failure` and `skipped` are preserved. Unknown conclusions normalize to `neutral`; unknown statuses normalize to `pending`.

Vela does not treat GitHub metadata as final launch proof. Imported PR files, reviews and check runs are readiness inputs. Merge queueing still requires local tenant checks, RBAC, merge gates, readiness state and evidence writes before any local merge candidate can move to `queued`.

The OpenAPI draft lives at `docs/openapi-v1.yaml`. Internal sidecar contracts remain under `services/*/README.md` until Rust/Python sidecars are implemented.

## Internal API Modules

The v1 API keeps route ownership in `VelaWeb.Api.V1.FoundationController`, but the controller is intentionally thin. Endpoint actions delegate shared behavior to focused modules:

- `VelaWeb.Api.V1.Response` owns pagination, schema serialization, validation errors and common error envelopes.
- `VelaWeb.Api.V1.IdempotentMutation` wraps mutating endpoints that support `Idempotency-Key`.
- `VelaWeb.Api.V1.MutationAudit` writes evidence and outbox rows for accepted mutations.
- `VelaWeb.Api.V1.RepoActions` owns repository import and PR sync orchestration.
- `VelaWeb.Api.V1.PullRequestActions` owns PR comments, reviewed merge queueing and merge cancellation.
- `VelaWeb.Api.V1.MergeActions` owns merge candidate simulation job orchestration.
- `VelaWeb.Api.V1.WebhookActions` owns provider webhook verification, tenant context validation and ingestion.
- `VelaWeb.Api.V1.ReadModels` owns read-side collection queries that do not belong in the controller.

This split keeps HTTP routing, response shape, idempotency, mutation audit, provider orchestration and read models independently testable while preserving the public route contract.
