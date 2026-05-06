## Summary

Describe the behavioral change and the affected Vela surface.

## Changed Areas

- [ ] `apps/web`
- [ ] `packages/protocol`
- [ ] `packages/sdk-js`
- [ ] `services/*`
- [ ] `docs`
- [ ] CI / repo tooling

## Verification

List exact commands and the result:

```text
./scripts/check.sh
```

If a check was skipped, explain why.

## Security / Trust Boundary

- [ ] API auth, tenant checks, or RBAC
- [ ] Webhook signatures or replay windows
- [ ] Merge gates or state transitions
- [ ] Evidence hashes, exports, or verifier behavior
- [ ] Idempotency or mutation audit writes
- [ ] Secret handling
- [ ] No security-sensitive boundary touched

Describe any fail-closed behavior, negative tests, or remaining risk.

## Contracts

List changed routes, schemas, event types, SDK methods, service boundaries, or
public docs.

## Follow-Ups

List intentionally deferred work.
