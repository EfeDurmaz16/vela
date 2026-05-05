# API

The backend exposes a versioned JSON surface under `/api/v1`. Collections return:

```json
{
  "data": [],
  "pagination": { "limit": 25, "returned": 0 }
}
```

Phase 0 route surface:

- `GET /api/v1/orgs`
- `GET /api/v1/repos`
- `POST /api/v1/repos/:id/import`
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
- `POST /api/v1/merge-candidates/:id/simulate`
- `GET /api/v1/releases`
- `GET /api/v1/evidence-events`
- `GET /api/v1/integrations`
- `GET /api/v1/service-connections`
- `GET /api/v1/environments`
- `POST /api/v1/webhooks/:provider`

Operational endpoints:

- `GET /health`
- `GET /ready`
- `GET /metrics`

Webhook events include `repo.push`, `pull_request.opened`, `pull_request.updated`, `analysis.completed`, `score.changed`, `merge.blocked`, `merge.completed` and `deployment.ready`. Signed webhook helpers use HMAC-SHA256 over `timestamp.body` with constant-time comparison.

The OpenAPI draft lives at `docs/openapi-v1.yaml`. Internal sidecar contracts remain under `services/*/README.md` until Rust/Python sidecars are implemented.
