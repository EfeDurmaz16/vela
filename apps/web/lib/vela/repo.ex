defmodule Vela.Repo do
  use Ecto.Repo,
    otp_app: :vela,
    adapter: Ecto.Adapters.Postgres

  @disable_parallel_preloads Application.compile_env(
                               :vela,
                               :disable_parallel_preloads,
                               false
                             )

  def default_options(:all) when @disable_parallel_preloads, do: [in_parallel: false]
  def default_options(_operation), do: []
end
