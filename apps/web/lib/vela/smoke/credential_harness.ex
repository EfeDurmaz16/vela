defmodule Vela.Smoke.CredentialHarness do
  @moduledoc """
  Non-destructive credential smoke checks for configured provider boundaries.
  """

  alias Vela.Auth.WorkOS
  alias Vela.Git.GitHubClient
  alias Vela.Storage.S3ObjectStore
  alias Vela.Webhooks

  @checks [:workos, :github, :s3, :webhooks]

  def run(opts \\ []) do
    checks = Keyword.get(opts, :checks, @checks)
    config = Keyword.get(opts, :config, &default_config/1)
    transports = Keyword.get(opts, :transports, %{})

    Enum.map(checks, fn check ->
      check(check, config.(config_key(check)), Map.get(transports, check))
    end)
  end

  def exit_status(results) do
    if Enum.any?(results, &(&1.status == :fail)), do: 1, else: 0
  end

  def format_results(results) do
    Enum.map(results, fn result ->
      status = result.status |> to_string() |> String.upcase()
      provider = to_string(result.provider)
      message = Map.get(result, :message) || default_message(result)

      line = "#{status} #{provider} #{message}"

      case result do
        %{status: :fail, reason: reason} -> "#{line}: #{inspect(reason)}"
        _ -> line
      end
    end)
  end

  defp check(:workos, config, transport) do
    attrs = normalize_config(config)

    with :ok <- require_keys(attrs, [:api_key, :smoke_session_id], :workos),
         {:ok, _session} <-
           WorkOS.verify_session(%{
             api_key: attrs.api_key,
             session_id: attrs.smoke_session_id,
             transport: transport
           }) do
      pass(:workos, "session credential verified")
    else
      {:skip, message} -> skip(:workos, message)
      {:error, reason} -> fail(:workos, "credential check failed", reason)
    end
  end

  defp check(:github, config, transport) do
    attrs = normalize_config(config)

    with :ok <- require_keys(attrs, [:token, :smoke_owner, :smoke_repo], :github),
         {:ok, _repository} <-
           GitHubClient.import_repository(%{
             token: attrs.token,
             owner: attrs.smoke_owner,
             repo: attrs.smoke_repo,
             transport: transport
           }) do
      pass(:github, "repository credential verified")
    else
      {:skip, message} -> skip(:github, message)
      {:error, reason} -> fail(:github, "credential check failed", reason)
    end
  end

  defp check(:s3, config, transport) do
    attrs = normalize_config(config)
    required = [:endpoint, :bucket, :region, :access_key_id, :secret_access_key, :smoke_key]

    with :ok <- require_keys(attrs, required, :s3),
         {:ok, _body} <-
           S3ObjectStore.get_object(%{
             endpoint: attrs.endpoint,
             bucket: attrs.bucket,
             region: attrs.region,
             access_key_id: attrs.access_key_id,
             secret_access_key: attrs.secret_access_key,
             key: attrs.smoke_key,
             transport: transport
           }) do
      pass(:s3, "read-only object credential verified")
    else
      {:skip, message} -> skip(:s3, message)
      {:error, reason} -> fail(:s3, "credential check failed", reason)
    end
  end

  defp check(:webhooks, config, _transport) do
    attrs = normalize_config(config)

    cond do
      has_secret?(attrs) ->
        secret = webhook_secret(attrs)
        timestamp = "2026-05-05T00:00:00Z"
        body = ~s({"type":"vela.smoke"})
        signature = Webhooks.sign(secret, timestamp, body)

        case Webhooks.verify_signature(secret, timestamp, body, signature) do
          :ok -> pass(:webhooks, "local signing secret verified")
          {:error, reason} -> fail(:webhooks, "credential check failed", reason)
        end

      true ->
        skip(:webhooks, "missing VELA_WEBHOOK_SECRET or provider webhook secret")
    end
  end

  defp default_config(:workos) do
    :vela
    |> Application.get_env(:workos, [])
    |> Keyword.merge(smoke_session_id: System.get_env("WORKOS_SMOKE_SESSION_ID"))
  end

  defp default_config(:github) do
    :vela
    |> Application.get_env(:github, [])
    |> Keyword.merge(
      smoke_owner: System.get_env("GITHUB_SMOKE_OWNER"),
      smoke_repo: System.get_env("GITHUB_SMOKE_REPO")
    )
  end

  defp default_config(:object_store) do
    :vela
    |> Application.get_env(:object_store, [])
    |> Keyword.merge(
      smoke_key: System.get_env("S3_SMOKE_KEY"),
      smoke_safe_prefix: System.get_env("S3_SMOKE_SAFE_PREFIX")
    )
  end

  defp default_config(:webhooks), do: Application.get_env(:vela, :webhooks, [])

  defp config_key(:s3), do: :object_store
  defp config_key(check), do: check

  defp require_keys(attrs, keys, provider) do
    missing =
      keys
      |> Enum.reject(fn key -> present?(Map.get(attrs, key)) end)
      |> Enum.map(&env_name(provider, &1))

    case missing do
      [] -> :ok
      _ -> {:skip, "missing #{Enum.join(missing, ", ")}"}
    end
  end

  defp env_name(:workos, :api_key), do: "WORKOS_API_KEY"
  defp env_name(:workos, :smoke_session_id), do: "WORKOS_SMOKE_SESSION_ID"
  defp env_name(:github, :token), do: "GITHUB_TOKEN"
  defp env_name(:github, :smoke_owner), do: "GITHUB_SMOKE_OWNER"
  defp env_name(:github, :smoke_repo), do: "GITHUB_SMOKE_REPO"
  defp env_name(:s3, :endpoint), do: "S3_ENDPOINT"
  defp env_name(:s3, :bucket), do: "S3_BUCKET"
  defp env_name(:s3, :region), do: "S3_REGION"
  defp env_name(:s3, :access_key_id), do: "S3_ACCESS_KEY_ID"
  defp env_name(:s3, :secret_access_key), do: "S3_SECRET_ACCESS_KEY"
  defp env_name(:s3, :smoke_key), do: "S3_SMOKE_KEY"
  defp env_name(_provider, key), do: key |> to_string() |> String.upcase()

  defp has_secret?(attrs), do: present?(webhook_secret(attrs))

  defp webhook_secret(attrs) do
    case Map.get(attrs, :default_secret) do
      value when is_binary(value) and value != "" ->
        value

      _ ->
        attrs
        |> Map.get(:secrets, %{})
        |> Enum.find_value(fn {_provider, secret} ->
          if present?(secret), do: secret
        end)
    end
  end

  defp normalize_config(config) when is_map(config), do: atomize_keys(config)
  defp normalize_config(config) when is_list(config), do: config |> Map.new() |> atomize_keys()
  defp normalize_config(_), do: %{}

  defp atomize_keys(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp present?(value), do: is_binary(value) and value != ""

  defp pass(provider, message), do: %{provider: provider, status: :pass, message: message}
  defp skip(provider, message), do: %{provider: provider, status: :skip, message: message}

  defp fail(provider, message, reason),
    do: %{provider: provider, status: :fail, message: message, reason: reason}

  defp default_message(%{status: :pass}), do: "ok"
  defp default_message(%{status: :skip}), do: "skipped"
  defp default_message(%{status: :fail}), do: "failed"
end
