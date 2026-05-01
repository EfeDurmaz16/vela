defmodule Vela.Repo do
  use Ecto.Repo,
    otp_app: :vela,
    adapter: Ecto.Adapters.Postgres
end
