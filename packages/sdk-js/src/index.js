export class VelaClient {
  constructor(options) {
    this.baseUrl = options.baseUrl.replace(/\/+$/, "");
    this.token = options.token;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async listRepositories() {
    const response = await this.request("/api/v1/repos");
    return response.data;
  }

  async importRepository(input) {
    const response = await this.request("/api/v1/repos/import", {
      method: "POST",
      body: JSON.stringify({
        owner: input.owner,
        repo: input.repo,
        provider: input.provider ?? "github"
      })
    });

    return response.data;
  }

  async syncPullRequest(input) {
    const response = await this.request(
      `/api/v1/repos/${encodeURIComponent(input.repositoryId)}/pull-requests/${input.pullRequestNumber}/sync`,
      {method: "POST"}
    );

    return response.data;
  }

  async request(path, init = {}) {
    const headers = new Headers(init.headers);
    headers.set("accept", "application/json");

    if (init.body && !headers.has("content-type")) {
      headers.set("content-type", "application/json");
    }

    if (this.token) {
      headers.set("authorization", `Bearer ${this.token}`);
    }

    const response = await this.fetchImpl(`${this.baseUrl}${path}`, {...init, headers});

    if (!response.ok) {
      throw new VelaApiError(response.status, await response.text());
    }

    return await response.json();
  }
}

export class VelaApiError extends Error {
  constructor(status, body) {
    super(`Vela API request failed with status ${status}`);
    this.name = "VelaApiError";
    this.status = status;
    this.body = body;
  }
}
