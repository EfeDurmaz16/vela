defmodule VelaWeb.Api.V1.PullRequestActions do
  @moduledoc """
  Pull request mutation actions for the v1 JSON API.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Vela.{Forge, Merge, Repo}
  alias VelaWeb.Api.V1.MutationAudit
  alias VelaWeb.Api.V1.Response

  def create_comment(conn, pull_request, body, params) do
    with {:ok, review} <-
           Forge.create_review(%{
             pull_request_id: pull_request.id,
             actor_id: conn.assigns.current_actor.id,
             status: "comment",
             summary: body
           }),
         {:ok, github_payload} <- maybe_publish_github_comment(pull_request, body, params),
         :ok <- MutationAudit.record_pr_comment!(conn, pull_request, review, github_payload) do
      conn
      |> put_status(:created)
      |> json(%{data: review |> Response.serialize() |> Map.put(:github, github_payload)})
    else
      {:error, %Ecto.Changeset{} = changeset} -> Response.validation_error(conn, changeset)
      {:error, reason} -> Response.github_error(conn, reason)
    end
  end

  def queue_merge(conn, pull_request) do
    with {:ok, candidate} <-
           Repo.transaction(fn ->
             case Merge.queue_after_successful_review(pull_request) do
               {:ok, candidate} ->
                 MutationAudit.record_merge_queued!(conn, pull_request, candidate)
                 candidate

               {:error, reason} ->
                 Repo.rollback(reason)
             end
           end) do
      conn
      |> put_status(:accepted)
      |> json(%{
        data: %{pull_request_id: pull_request.id, merge_candidate: Response.serialize(candidate)}
      })
    else
      {:error, reason} -> Response.merge_gate_error(conn, reason)
    end
  end

  defp maybe_publish_github_comment(pull_request, body, %{"publish_to_github" => true}) do
    repository = pull_request.repository
    config = Application.get_env(:vela, :github, [])

    with "github" <- repository.provider,
         number when is_integer(number) <- pull_request.external_number,
         [owner, repo] <- String.split(repository.full_name || "", "/", parts: 2),
         {:ok, github_comment} <-
           Vela.Git.GitHubClient.create_issue_comment(%{
             owner: owner,
             repo: repo,
             number: number,
             body: body,
             token: Keyword.get(config, :token),
             transport: Keyword.get(config, :transport)
           }) do
      {:ok, github_comment}
    else
      other -> {:error, {:github_comment_unavailable, other}}
    end
  end

  defp maybe_publish_github_comment(_pull_request, _body, _params), do: {:ok, nil}
end
