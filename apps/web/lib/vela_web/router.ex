defmodule VelaWeb.Router do
  use VelaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VelaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_session do
    plug :fetch_session
  end

  pipeline :authenticated_api do
    plug VelaWeb.Plugs.ApiAuth
  end

  scope "/", VelaWeb do
    pipe_through :browser

    live "/", AppLive, :home
    live "/repos", AppLive, :repos
    live "/repos/:org/:repo", AppLive, :repo
    live "/repos/:org/:repo/pulls/:id", AppLive, :pull
    live "/agents", AppLive, :agents
    live "/agents/:id", AppLive, :agent_profile
    live "/launches", AppLive, :launches
    live "/evidence", AppLive, :evidence
    live "/settings", AppLive, :settings
  end

  scope "/", VelaWeb do
    get "/health", HealthController, :health
    get "/ready", HealthController, :ready
    get "/metrics", HealthController, :metrics
  end

  scope "/api/v1", VelaWeb.Api.V1 do
    pipe_through :api

    get "/orgs", FoundationController, :orgs
    get "/repos", FoundationController, :repos
    get "/repos/:id/trust", FoundationController, :repo_trust
    get "/changes", FoundationController, :changes
    get "/changes/:id/readiness", FoundationController, :change_readiness
    get "/pull-requests", FoundationController, :pull_requests
    get "/agents", FoundationController, :agents
    get "/agents/:id/sessions", FoundationController, :agent_sessions
    get "/agents/:id/policies", FoundationController, :agent_policies
    get "/analysis-runs", FoundationController, :analysis_runs
    get "/readiness-scores", FoundationController, :readiness_scores
    get "/merge-candidates", FoundationController, :merge_candidates
    get "/releases", FoundationController, :releases
    get "/evidence-events", FoundationController, :evidence_events
    get "/integrations", FoundationController, :integrations
    get "/service-connections", FoundationController, :service_connections
    get "/environments", FoundationController, :environments
    post "/webhooks/:provider", FoundationController, :webhook
  end

  scope "/api/v1", VelaWeb.Api.V1 do
    pipe_through [:api, :api_session]

    get "/auth/workos/login", WorkOSAuthController, :login
    get "/auth/workos/callback", WorkOSAuthController, :callback
  end

  scope "/api/v1", VelaWeb.Api.V1 do
    pipe_through [:api, :api_session, :authenticated_api]

    post "/repos", FoundationController, :create_repo
    get "/repos/:id", FoundationController, :show_repo
    put "/repos/:id", FoundationController, :update_repo
    delete "/repos/:id", FoundationController, :delete_repo
    post "/repos/:id/import", FoundationController, :import_repo
    post "/merge-candidates/:id/simulate", FoundationController, :simulate_merge
  end

  # Other scopes may use custom stacks.
  # scope "/api", VelaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:vela, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VelaWeb.Telemetry
    end
  end
end
