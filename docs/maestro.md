# Vela Maestro

Vela Maestro is the launch readiness engine.

It evaluates behavioral impact, correctness, security, performance, UX, API compatibility, test evidence, rollback safety and agent provenance. It returns an overall readiness score, ship/wait/block verdict, confidence, blocking findings and required actions.

Phase 0 implements deterministic Phoenix-local scoring and stores persisted scores. Python FastAPI service contracts are documented but not run. Later phases add Playwright, Pytest, Semgrep, API contract analysis, performance benchmarks, tree-sitter and LLM provider abstractions.
