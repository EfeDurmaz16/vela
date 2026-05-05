defmodule Vela.HTTP do
  @moduledoc """
  Small HTTP boundary around Req with an injectable transport for deterministic tests.
  """

  def request(opts) do
    transport = Keyword.get(opts, :transport)
    method = Keyword.fetch!(opts, :method)
    url = opts |> Keyword.fetch!(:url) |> URI.parse()

    headers =
      opts
      |> Keyword.get(:headers, [])
      |> Enum.map(fn {key, value} -> {key |> to_string() |> String.downcase(), value} end)

    body = Keyword.get(opts, :body)

    request = %{method: method, url: url, headers: headers, body: body}

    if transport do
      transport.(request)
    else
      opts
      |> Keyword.put(:headers, headers)
      |> Keyword.delete(:transport)
      |> Req.request()
      |> normalize_response()
    end
  end

  defp normalize_response({:ok, %Req.Response{} = response}),
    do: {:ok, %{status: response.status, headers: response.headers, body: response.body}}

  defp normalize_response(other), do: other
end
