defmodule VelaWeb.Plugs.ApiAuth do
  @moduledoc """
  Loads the authenticated API identity from the Phoenix session.

  The session stores only stable record identifiers. Each protected request
  rehydrates and validates the user, organization, membership, and actor so
  deleted or mismatched identity state does not continue to authorize requests.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Vela.Accounts.{Membership, Organization, User}
  alias Vela.Actors.Actor
  alias Vela.Repo

  @session_key "vela_api_auth"
  @error %{error: %{code: "api_auth_required"}}

  def session_key, do: @session_key

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> get_session(@session_key)
    |> load_identity()
    |> case do
      {:ok, identity} -> assign_identity(conn, identity)
      :error -> reject(conn)
    end
  end

  defp load_identity(%{
         "user_id" => user_id,
         "organization_id" => organization_id,
         "membership_id" => membership_id,
         "actor_id" => actor_id
       }) do
    with %User{} = user <- Repo.get(User, user_id),
         %Organization{} = organization <- Repo.get(Organization, organization_id),
         %Membership{} = membership <- Repo.get(Membership, membership_id),
         %Actor{} = actor <- Repo.get(Actor, actor_id),
         true <- membership.user_id == user.id,
         true <- membership.organization_id == organization.id,
         true <- actor.organization_id == organization.id,
         true <- actor.created_by_user_id == user.id do
      {:ok,
       %{
         user: user,
         organization: organization,
         membership: membership,
         actor: actor
       }}
    else
      _ -> :error
    end
  end

  defp load_identity(_session), do: :error

  defp assign_identity(conn, identity) do
    conn
    |> assign(:current_user, identity.user)
    |> assign(:current_organization, identity.organization)
    |> assign(:current_membership, identity.membership)
    |> assign(:current_actor, identity.actor)
  end

  defp reject(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(@error)
    |> halt()
  end
end
