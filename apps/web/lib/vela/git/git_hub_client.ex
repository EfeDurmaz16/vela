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
         provider: "github",
         html_url: repo["html_url"]
       }}
    end
  end

  @impl Vela.Git.GitProvider
  def mirror_repository(attrs), do: import_repository(attrs)

  @impl Vela.Git.GitProvider
  def fetch_pull_request(attrs) do
    with {:ok, pr} <-
           get_json(
             attrs,
             "/repos/#{owner(attrs)}/#{repo(attrs)}/pulls/#{Map.fetch!(attrs, :number)}"
           ) do
      {:ok,
       %{
         external_id: pr["id"],
         external_number: pr["number"],
         title: pr["title"],
         description: pr["body"],
         html_url: pr["html_url"],
         status: normalize_pull_request_status(pr),
         source_branch: get_in(pr, ["head", "ref"]),
         target_branch: get_in(pr, ["base", "ref"]),
         head_sha: get_in(pr, ["head", "sha"]),
         base_sha: get_in(pr, ["base", "sha"]),
         author_login: get_in(pr, ["user", "login"])
       }}
    end
  end

  def list_pull_request_files(attrs) do
    with {:ok, files} <-
           get_json(
             attrs,
             "/repos/#{owner(attrs)}/#{repo(attrs)}/pulls/#{Map.fetch!(attrs, :number)}/files?per_page=100"
           ) do
      {:ok, Enum.map(files, &normalize_pull_request_file/1)}
    end
  end

  def list_pull_request_reviews(attrs) do
    with {:ok, reviews} <-
           get_json(
             attrs,
             "/repos/#{owner(attrs)}/#{repo(attrs)}/pulls/#{Map.fetch!(attrs, :number)}/reviews?per_page=100"
           ) do
      {:ok, Enum.map(reviews, &normalize_pull_request_review/1)}
    end
  end

  def create_issue_comment(attrs) do
    path = "/repos/#{owner(attrs)}/#{repo(attrs)}/issues/#{Map.fetch!(attrs, :number)}/comments"

    with {:ok, body} <- post_json(attrs, path, %{"body" => Map.fetch!(attrs, :body)}) do
      {:ok,
       %{
         external_id: body["id"],
         html_url: body["html_url"],
         body: body["body"]
       }}
    end
  end

  def list_branches(attrs) do
    with {:ok, branches} <-
           get_json(attrs, "/repos/#{owner(attrs)}/#{repo(attrs)}/branches?per_page=100") do
      {:ok, Enum.map(branches, &normalize_branch/1)}
    end
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

  defp post_json(attrs, path, body) do
    [
      method: :post,
      url: @api_base <> path,
      headers: github_headers(attrs),
      json: body,
      body: body,
      transport: Map.get(attrs, :transport)
    ]
    |> Vela.HTTP.request()
    |> handle_response()
  end

  defp github_headers(attrs) do
    [
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"},
      {"user-agent", "vela"}
    ] ++ auth_headers(attrs)
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

  defp normalize_branch(branch),
    do: %{
      name: branch["name"],
      current_sha: get_in(branch, ["commit", "sha"]),
      protected: Map.get(branch, "protected", false)
    }

  defp normalize_pull_request_file(file), do: Vela.Git.DiffModel.github_file_attrs(file)

  defp normalize_pull_request_review(review),
    do: %{
      external_id: review["id"],
      external_author_login: get_in(review, ["user", "login"]),
      status: normalize_review_state(review["state"]),
      summary: review["body"],
      submitted_at: parse_datetime(review["submitted_at"])
    }

  defp normalize_pull_request_status(%{"draft" => true}), do: "draft"
  defp normalize_pull_request_status(%{"state" => "closed", "merged" => true}), do: "merged"
  defp normalize_pull_request_status(%{"state" => "closed"}), do: "closed"
  defp normalize_pull_request_status(%{"state" => "open"}), do: "ready_for_review"
  defp normalize_pull_request_status(_), do: "open"

  defp normalize_review_state("APPROVED"), do: "approve"
  defp normalize_review_state("CHANGES_REQUESTED"), do: "request_changes"
  defp normalize_review_state("COMMENTED"), do: "comment"
  defp normalize_review_state(_state), do: "comment"

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      _ -> nil
    end
  end
end
