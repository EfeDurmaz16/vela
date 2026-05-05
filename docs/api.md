# API

The backend exposes a versioned JSON surface under `/api/v1`. Collections return:

```json
{
  "data": [],
  "pagination": { "limit": 25, "returned": 0 }
}
```

Phase 0 route surface:

Public/read-only routes:

- `GET /api/v1/orgs`
- `GET /api/v1/repos`
- `GET /api/v1/repos/:id/trust`
- `GET /api/v1/changes`
- `GET /api/v1/changes/:id/readiness`
- `GET /api/v1/pull-requests`
- `GET /api/v1/agents`
- `GET /api/v1/agents/:id/sessions`
- `GET /api/v1/agents/:id/policies`
- `GET /api/v1/analysis-runs`
- `GET /api/v1/readiness-scores`
- `GET /api/v1/merge-candidates`
- `GET /api/v1/releases`
- `GET /api/v1/evidence-events`
- `GET /api/v1/integrations`
- `GET /api/v1/service-connections`
- `GET /api/v1/environments`
- `POST /api/v1/webhooks/:provider`

WorkOS session routes:

- `GET /api/v1/auth/workos/login`
- `GET /api/v1/auth/workos/callback`

Authenticated API routes:

- `POST /api/v1/repos/:id/import`
- `POST /api/v1/merge-candidates/:id/simulate`

Operational endpoints:

- `GET /health`
- `GET /ready`
- `GET /metrics`

Webhook events include `repo.push`, `pull_request.opened`, `pull_request.updated`, `analysis.completed`, `score.changed`, `merge.blocked`, `merge.completed` and `deployment.ready`. Provider webhook verification uses provider-native signatures when available: GitHub `x-hub-signature-256`, Stripe `stripe-signature`, WorkOS `workos-signature`, and Svix-style `svix-id`, `svix-timestamp`, `svix-signature`. Other providers continue to use HMAC-SHA256 over `timestamp.body` with `x-vela-timestamp` and `x-vela-signature` or equivalent `x-webhook-*` headers. Comparisons are constant-time. Timestamped signatures are rejected outside the configured replay window, and webhook actor/repository context must belong to the supplied organization before evidence is written.

WorkOS AuthKit is handled server-side: the login route returns a WorkOS authorization URL and the callback route exchanges the returned code with WorkOS before reconciling Vela user, organization, membership and human actor records. On successful callback, Vela stores a compact `vela_api_auth` identity reference in the signed Phoenix session cookie. Protected API routes rehydrate `current_user`, `current_organization`, `current_membership`, and `current_actor` from those IDs on each request; missing, deleted, or mismatched records return `401 {"error":{"code":"api_auth_required"}}`.

The read-only collection endpoints intentionally remain public in phase 0 so existing demos, smoke checks, and API surface tests do not need a browser-authenticated session. Mutating job routes are the first authenticated scope because they require tenant context before enqueueing work. Those mutating routes support `Idempotency-Key`: reusing the same key with the same request body replays the first response without enqueueing another job, while reusing the same key with a different request returns `409 {"error":{"code":"idempotency_key_reused"}}`. Accepted mutations write a hash-chained evidence event and a pending outbox event in the same database transaction as the queued Oban job.

The OpenAPI draft lives at `docs/openapi-v1.yaml`. Internal sidecar contracts remain under `services/*/README.md` until Rust/Python sidecars are implemented.
