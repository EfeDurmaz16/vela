defmodule Vela.Auth.WorkOS do
  @moduledoc "WorkOS SSO boundary for human authentication."

  @callback authorization_url(map()) :: {:ok, URI.t()} | {:error, term()}
  @callback exchange_code(map()) :: {:ok, map()} | {:error, term()}
  @callback verify_session(map()) :: {:ok, map()} | {:error, term()}

  @api_base "https://api.workos.com"

  def authorization_url(attrs) do
    with {:ok, client_id} <- fetch(attrs, :client_id),
         {:ok, redirect_uri} <- fetch(attrs, :redirect_uri) do
      params =
        attrs
        |> take_optional([:state, :connection_id, :organization_id, :login_hint, :domain_hint])
        |> Map.merge(%{
          "client_id" => client_id,
          "redirect_uri" => redirect_uri,
          "response_type" => "code",
          "provider" => Map.get(attrs, :provider, "authkit")
        })

      {:ok, URI.parse(@api_base <> "/user_management/authorize?" <> URI.encode_query(params))}
    end
  end

  def exchange_code(attrs) do
    with {:ok, api_key} <- fetch(attrs, :api_key),
         {:ok, client_id} <- fetch(attrs, :client_id),
         {:ok, code} <- fetch(attrs, :code) do
      request(
        :post,
        "/user_management/authenticate",
        api_key,
        %{
          "grant_type" => "authorization_code",
          "client_id" => client_id,
          "code" => code,
          "ip_address" => Map.get(attrs, :ip_address),
          "user_agent" => Map.get(attrs, :user_agent)
        },
        attrs
      )
    end
  end

  def verify_session(attrs) do
    with {:ok, api_key} <- fetch(attrs, :api_key),
         {:ok, session_id} <- fetch(attrs, :session_id) do
      request(:get, "/user_management/sessions/#{URI.encode(session_id)}", api_key, nil, attrs)
    end
  end

  defp request(method, path, api_key, body, attrs) do
    headers = [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]

    [
      method: method,
      url: @api_base <> path,
      headers: headers,
      json: body,
      body: body,
      transport: Map.get(attrs, :transport)
    ]
    |> Vela.HTTP.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, {:workos_error, status, body}}

  defp handle_response({:error, reason}), do: {:error, reason}

  defp fetch(attrs, key) do
    case Map.get(attrs, key) || Map.get(attrs, to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:missing_config, key}}
    end
  end

  defp take_optional(attrs, keys) do
    keys
    |> Enum.reduce(%{}, fn key, acc ->
      case Map.get(attrs, key) do
        nil -> acc
        value -> Map.put(acc, key |> to_string() |> String.replace("_", "-"), value)
      end
    end)
  end
end
