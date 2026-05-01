defmodule VelaWeb.PageController do
  use VelaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
