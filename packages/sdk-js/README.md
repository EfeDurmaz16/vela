# Vela JavaScript SDK

Minimal dependency-free client for the Vela v1 API.

```ts
import {VelaClient} from "@vela/sdk-js";

const vela = new VelaClient({
  baseUrl: "https://vela.example.com",
  token: process.env.VELA_API_TOKEN
});

const repositories = await vela.listRepositories();
await vela.importRepository({owner: "sardis-labs", repo: "vela"});
await vela.syncPullRequest({repositoryId: repositories[0].id, pullRequestNumber: 17});
```

The SDK intentionally wraps only the Phase 0 integration path: list
repositories, queue a GitHub repository import, and queue a pull request sync.
