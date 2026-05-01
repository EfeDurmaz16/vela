# API

Phase 0 focuses on the Phoenix UI and internal context APIs. Public REST endpoints are planned for:

- `/repos`
- `/pulls`
- `/issues`
- `/agents`
- `/analysis-runs`
- `/readiness-scores`
- `/pipeline-runs`
- `/policies`
- `/webhooks`

Webhook events include `repo.push`, `pull_request.opened`, `pull_request.updated`, `analysis.completed`, `score.changed`, `merge.blocked`, `merge.completed` and `deployment.ready`.

Internal service communication is documented as HTTP/gRPC-style contracts under `services/*/contracts`.
