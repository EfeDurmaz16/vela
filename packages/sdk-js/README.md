# Vela JavaScript SDK

Minimal dependency-free client for the Vela v1 API.

## Quickstart

Set the same API base URL and bearer token you would use with raw HTTP:

```sh
export VELA_BASE_URL="https://vela.example.com"
export VELA_API_TOKEN="vela_token_..."
```

Queue a GitHub repository import with curl:

```sh
curl -sS "$VELA_BASE_URL/api/v1/repos/import" \
  -H "authorization: Bearer $VELA_API_TOKEN" \
  -H "content-type: application/json" \
  -H "idempotency-key: repo-import-sardis-vela-001" \
  -d '{"owner":"sardis-labs","repo":"vela","provider":"github"}'
```

Queue a pull request sync with curl:

```sh
curl -sS "$VELA_BASE_URL/api/v1/repos/repo_123/sync-pull-request" \
  -H "authorization: Bearer $VELA_API_TOKEN" \
  -H "content-type: application/json" \
  -H "idempotency-key: pr-sync-repo-123-17-001" \
  -d '{"number":17}'
```

Use the SDK for the same Phase 0 integration path:

```ts
import {VelaClient} from "@vela/sdk-js";

const vela = new VelaClient({
  baseUrl: process.env.VELA_BASE_URL!,
  token: process.env.VELA_API_TOKEN
});

const repositories = await vela.listRepositories();

const {repository, job: importJob} = await vela.importRepository({
  owner: "sardis-labs",
  repo: "vela"
});

const {job: syncJob} = await vela.syncPullRequest({
  repositoryId: repository.id,
  pullRequestNumber: 17
});

console.log({
  repository_count: repositories.length,
  import_job: importJob.id,
  sync_job: syncJob.id
});
```

The SDK intentionally wraps only the Phase 0 integration path: list
repositories, queue a GitHub repository import, and queue a pull request sync.
Mutating routes support `Idempotency-Key` at the HTTP layer; the SDK currently
keeps request construction minimal and does not generate idempotency keys for
callers.
