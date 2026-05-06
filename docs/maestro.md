# Vela Maestro

Vela Maestro is the launch readiness engine.

It evaluates behavioral impact, correctness, security, performance, UX, API compatibility, test evidence, rollback safety and agent provenance. It returns an overall readiness score, ship/wait/block verdict, confidence, blocking findings and required actions.

Phase 0 implements deterministic Phoenix-local scoring and stores persisted scores. Python FastAPI service contracts are documented but not run. Later phases add Playwright, Pytest, Semgrep, API contract analysis, performance benchmarks, tree-sitter and LLM provider abstractions.

## Deterministic Local Analysis

The implemented local analyzer is deliberately small and reproducible. It reads persisted pull request file metadata and derives:

- `change_risk` from changed file count, sensitive paths and config paths.
- `test_evidence` from changed test/spec paths relative to sensitive paths.
- `security` from auth, billing, payment, token, wallet, signing, webhook, policy and production config paths.
- structured findings such as `sensitive paths changed`, `configuration paths changed` and `sensitive change has no test path evidence`.

`Vela.Jobs.ScoreRecalculationWorker` runs this analyzer, creates a `ReadinessScore`, persists `input_refs` pointing at PR files, reviews and check runs, and writes `score.computed` evidence. This is not an LLM judgment. It is a deterministic baseline that can be rerun and explained from local database rows.

## External Analysis Callbacks

External analyzers report completion through `POST /api/v1/analysis-runs/:id/callback`. The callback uses the same signed webhook infrastructure as provider webhooks with the `analysis` provider secret. A valid callback can move an `AnalysisRun` to `completed`, `failed` or `cancelled`, set a summary and set `completed_at`.

External analysis is additive. It does not replace deterministic gates, merge queue checks, evidence-chain verification or human/RBAC controls. Later LLM-backed analyzers must write their inputs and findings as reconstructable evidence instead of acting as hidden authority.
