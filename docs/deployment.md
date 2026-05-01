# Deployment

Local development uses Phoenix, Postgres and mock-backed service interfaces.

Phase 0 commands:

```bash
./scripts/setup.sh
./scripts/dev.sh
./scripts/check.sh
```

The first deployable shape is a single Phoenix app with Postgres. Object storage, Rust services, Python Maestro, runner coordination and search services are introduced in later phases.

Future deployment targets include Fly, single-tenant infrastructure and Kubernetes. Kubernetes is not a Phase 0 goal.
