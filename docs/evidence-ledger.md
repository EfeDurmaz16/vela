# Evidence Ledger

Every important action in Vela should produce evidence.

Evidence events are append-only, actor-bound, resource-bound, timestamped, payload-hashed and hash-chained. Signatures are optional in Phase 0 and become mandatory for critical machine actors later.

The ledger enables reconstruction: who acted, what changed, what policy was evaluated, which score was computed, which merge candidate was simulated and why the final decision was made.

## Chain Model

Evidence is chained per scope:

- Organization-level events use `organization_id` with `repository_id = nil`.
- Repository-level events use both `organization_id` and `repository_id`.

Each event stores:

- `payload_hash`: canonical JSON hash of the event payload.
- `prev_event_hash`: previous event hash in the same scope.
- `event_hash`: canonical hash of the event envelope, including `payload_hash`, `prev_event_hash`, actor, resource and timestamp.

Critical events must include an explicit actor. System actions should use a trusted system actor such as `Vela Merge`, not a null actor.

## Verification

The verifier recomputes the chain from persisted rows and reports the first broken event. It checks:

- previous hash continuity
- payload hash integrity
- event envelope hash integrity

API:

```bash
curl "http://localhost:4000/api/v1/evidence-events/verify?organization_id=<org-id>"
curl "http://localhost:4000/api/v1/evidence-events/verify?organization_id=<org-id>&repository_id=<repo-id>"
```

Healthy response:

```json
{
  "data": {
    "valid": true,
    "organization_id": "org-id",
    "repository_id": "repo-id",
    "count": 12,
    "last_hash": "sha256:..."
  }
}
```

Broken response:

```json
{
  "data": {
    "valid": false,
    "organization_id": "org-id",
    "repository_id": "repo-id",
    "reason": "payload_hash_mismatch",
    "event_id": "event-id",
    "event_hash": "sha256:..."
  }
}
```

Failed verification records one open tamper alarm keyed by organization, event hash and reason. Rechecking the same broken chain does not create duplicate alarms.

## Export

Use `Vela.Evidence.export_events/2` for stable cursor export from application code or Mix tasks:

```elixir
page = Vela.Evidence.export_events(org_id, limit: 100)
next_page = Vela.Evidence.export_events(org_id, limit: 100, after: page.next_cursor)
repo_page = Vela.Evidence.export_events(org_id, repository_id: repo_id, limit: 100)
```

The cursor contains `inserted_at` and `id`. Ordering is stable by `inserted_at ASC, id ASC`, so events sharing the same timestamp do not get skipped or duplicated across pages.

## Event Types

Accepted event types live in `Vela.Evidence.EventTypes`. Unknown critical event names are rejected by the evidence schema. Add new event types to the registry before writing production code that emits them.
