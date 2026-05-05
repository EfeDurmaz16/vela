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

Webhook events include `repo.push`, `pull_request.opened`, `pull_request.updated`, `analysis.completed`, `score.changed`, `merge.blocked`, `merge.completed` and `deployment.ready`. Signed webhook helpers use HMAC-SHA256 over `timestamp.body` with constant-time comparison. When a provider secret is configured, webhook requests must include `x-vela-timestamp` and `x-vela-signature` or the equivalent `x-webhook-*` headers.

WorkOS AuthKit is handled server-side: the login route returns a WorkOS authorization URL and the callback route exchanges the returned code with WorkOS before reconciling Vela user, organization, membership and human actor records. On successful callback, Vela stores a compact `vela_api_auth` identity reference in the signed Phoenix session cookie. Protected API routes rehydrate `current_user`, `current_organization`, `current_membership`, and `current_actor` from those IDs on each request; missing, deleted, or mismatched records return `401 {"error":{"code":"api_auth_required"}}`.

The read-only collection endpoints intentionally remain public in phase 0 so existing demos, smoke checks, and API surface tests do not need a browser-authenticated session. Mutating job routes are the first authenticated scope because they require tenant context before enqueueing work.

The OpenAPI draft lives at `docs/openapi-v1.yaml`. Internal sidecar contracts remain under `services/*/README.md` until Rust/Python sidecars are implemented.
