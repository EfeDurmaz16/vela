defmodule Vela.Git.GitHubClient do
  @moduledoc """
  GitHub REST adapter for repository import, refs, PR metadata and compare diffs.
  """

  @behaviour Vela.Git.GitProvider
  @behaviour Vela.Git.DiffService
  @behaviour Vela.Git.RefService

  @api_base "https://api.github.com"

  @impl Vela.Git.GitProvider
  def import_repository(attrs) do
    with {:ok, repo} <- get_json(attrs, "/repos/#{owner(attrs)}/#{repo(attrs)}") do
      {:ok,
       %{
         external_id: repo["id"],
         name: repo["name"],
         slug: repo["name"],
         full_name: repo["full_name"],
         visibility: if(repo["private"], do: "private", else: "public"),
         default_branch: repo["default_branch"],
         provider: "github"
       }}
    end
  end

  @impl Vela.Git.GitProvider
  def mirror_repository(attrs), do: import_repository(attrs)

  @impl Vela.Git.GitProvider
  def fetch_pull_request(attrs) do
    get_json(attrs, "/repos/#{owner(attrs)}/#{repo(attrs)}/pulls/#{Map.fetch!(attrs, :number)}")
  end

  @impl Vela.Git.RefService
  def list_refs(attrs) do
    with {:ok, refs} <-
           get_json(
             attrs,
             "/repos/#{owner(attrs)}/#{repo(attrs)}/git/matching-refs/#{Map.get(attrs, :namespace, "heads")}"
           ) do
      {:ok, Enum.map(refs, &normalize_ref/1)}
    end
  end

  @impl Vela.Git.RefService
  def resolve_ref(attrs) do
    with {:ok, ref} <-
           get_json(
             attrs,
             "/repos/#{owner(attrs)}/#{repo(attrs)}/git/ref/#{Map.fetch!(attrs, :ref)}"
           ) do
      {:ok, normalize_ref(ref)}
    end
  end

  @impl Vela.Git.RefService
  def lease_ref(attrs), do: resolve_ref(attrs)

  @impl Vela.Git.DiffService
  def diff(attrs), do: compare(attrs)

  @impl Vela.Git.DiffService
  def changed_paths(attrs) do
    with {:ok, compare} <- compare(attrs) do
      {:ok, compare.files |> Enum.map(& &1.filename)}
    end
  end

  def compare(attrs) do
    path =
      "/repos/#{owner(attrs)}/#{repo(attrs)}/compare/#{Map.fetch!(attrs, :base)}...#{Map.fetch!(attrs, :head)}"

    with {:ok, body} <- get_json(attrs, path) do
      {:ok,
       %{
         status: body["status"],
         ahead_by: body["ahead_by"],
         behind_by: body["behind_by"],
         files:
           Enum.map(
             body["files"] || [],
             &%{filename: &1["filename"], status: &1["status"], patch: &1["patch"]}
           )
       }}
    end
  end

  defp get_json(attrs, path) do
    headers =
      [
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", "2022-11-28"},
        {"user-agent", "vela"}
      ] ++ auth_headers(attrs)

    [
      method: :get,
      url: @api_base <> path,
      headers: headers,
      transport: Map.get(attrs, :transport)
    ]
    |> Vela.HTTP.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, {:github_error, status, body}}

  defp handle_response({:error, reason}), do: {:error, reason}

  defp auth_headers(%{token: token}) when is_binary(token) and token != "",
    do: [{"authorization", "Bearer #{token}"}]

  defp auth_headers(_), do: []

  defp owner(attrs), do: Map.fetch!(attrs, :owner)
  defp repo(attrs), do: Map.fetch!(attrs, :repo)

  defp normalize_ref(ref),
    do: %{
      ref: ref["ref"],
      sha: get_in(ref, ["object", "sha"]),
      type: get_in(ref, ["object", "type"])
    }
end
