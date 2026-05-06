import assert from "node:assert/strict";
import test from "node:test";
import {VelaApiError, VelaClient} from "../src/index.js";

test("listRepositories serializes GET request with auth header", async () => {
  const calls = [];
  const client = new VelaClient({
    baseUrl: "https://vela.test/",
    token: "token_123",
    fetchImpl: async (url, init) => {
      calls.push({url, init});
      return jsonResponse({data: [{id: "repo_1", name: "core", slug: "core"}]});
    }
  });

  const repos = await client.listRepositories();

  assert.deepEqual(repos, [{id: "repo_1", name: "core", slug: "core"}]);
  assert.equal(calls[0].url, "https://vela.test/api/v1/repos");
  assert.equal(calls[0].init.headers.get("authorization"), "Bearer token_123");
  assert.equal(calls[0].init.headers.get("accept"), "application/json");
});

test("importRepository serializes GitHub import body", async () => {
  const calls = [];
  const client = new VelaClient({
    baseUrl: "https://vela.test",
    fetchImpl: async (url, init) => {
      calls.push({url, init});
      return jsonResponse({
        data: {
          repository: {id: "repo_1", name: "vela", slug: "vela"},
          job: {id: 1, status: "queued", kind: "repo_import"}
        }
      });
    }
  });

  const result = await client.importRepository({owner: "sardis-labs", repo: "vela"});

  assert.equal(calls[0].url, "https://vela.test/api/v1/repos/import");
  assert.equal(calls[0].init.method, "POST");
  assert.equal(calls[0].init.headers.get("content-type"), "application/json");
  assert.deepEqual(JSON.parse(calls[0].init.body), {
    owner: "sardis-labs",
    repo: "vela",
    provider: "github"
  });
  assert.equal(result.job.kind, "repo_import");
});

test("syncPullRequest URL-encodes repository id", async () => {
  const calls = [];
  const client = new VelaClient({
    baseUrl: "https://vela.test",
    fetchImpl: async (url, init) => {
      calls.push({url, init});
      return jsonResponse({
        data: {repository_id: "owner/repo", job: {id: 2, status: "queued", kind: "repo_sync"}}
      });
    }
  });

  const result = await client.syncPullRequest({repositoryId: "owner/repo", pullRequestNumber: 17});

  assert.equal(calls[0].url, "https://vela.test/api/v1/repos/owner%2Frepo/sync-pull-request");
  assert.equal(calls[0].init.method, "POST");
  assert.deepEqual(JSON.parse(calls[0].init.body), {number: 17});
  assert.equal(result.job.kind, "repo_sync");
});

test("request throws VelaApiError for failed responses", async () => {
  const client = new VelaClient({
    baseUrl: "https://vela.test",
    fetchImpl: async () =>
      new Response(JSON.stringify({error: {code: "denied"}}), {
        status: 403,
        headers: {"content-type": "application/json"}
      })
  });

  await assert.rejects(() => client.listRepositories(), error => {
    assert.ok(error instanceof VelaApiError);
    assert.equal(error.status, 403);
    assert.match(error.body, /denied/);
    return true;
  });
});

function jsonResponse(body) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {"content-type": "application/json"}
  });
}
