export type VelaClientOptions = {
  baseUrl: string;
  token?: string;
  fetchImpl?: typeof fetch;
};

export type VelaRepository = {
  id: string;
  name: string;
  slug: string;
  organization_id?: string;
  provider?: string | null;
  full_name?: string | null;
  import_status?: string | null;
};

export type VelaJob = {
  id: number | string;
  status: string;
  kind: string;
  queue?: string;
};

export type ImportRepositoryInput = {
  owner: string;
  repo: string;
  provider?: "github";
};

export type SyncPullRequestInput = {
  repositoryId: string;
  pullRequestNumber: number;
};

type ApiResponse<T> = {
  data: T;
};

export class VelaClient {
  private readonly baseUrl: string;
  private readonly token?: string;
  private readonly fetchImpl: typeof fetch;

  constructor(options: VelaClientOptions) {
    this.baseUrl = options.baseUrl.replace(/\/+$/, "");
    this.token = options.token;
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async listRepositories(): Promise<VelaRepository[]> {
    const response = await this.request<ApiResponse<VelaRepository[]>>("/api/v1/repos");
    return response.data;
  }

  async importRepository(input: ImportRepositoryInput): Promise<{
    repository: VelaRepository;
    job: VelaJob;
  }> {
    const response = await this.request<ApiResponse<{ repository: VelaRepository; job: VelaJob }>>(
      "/api/v1/repos/import",
      {
        method: "POST",
        body: JSON.stringify({
          owner: input.owner,
          repo: input.repo,
          provider: input.provider ?? "github"
        })
      }
    );

    return response.data;
  }

  async syncPullRequest(input: SyncPullRequestInput): Promise<{
    repository_id: string;
    job: VelaJob;
  }> {
    const response = await this.request<ApiResponse<{ repository_id: string; job: VelaJob }>>(
      `/api/v1/repos/${encodeURIComponent(input.repositoryId)}/sync-pull-request`,
      {
        method: "POST",
        body: JSON.stringify({number: input.pullRequestNumber})
      }
    );

    return response.data;
  }

  private async request<T>(path: string, init: RequestInit = {}): Promise<T> {
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

    return (await response.json()) as T;
  }
}

export class VelaApiError extends Error {
  readonly status: number;
  readonly body: string;

  constructor(status: number, body: string) {
    super(`Vela API request failed with status ${status}`);
    this.name = "VelaApiError";
    this.status = status;
    this.body = body;
  }
}
