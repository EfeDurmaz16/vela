defmodule Vela.Maestro.LocalAnalyzers do
  @moduledoc """
  Deterministic local analyzers for Phase 0 readiness.

  These analyzers intentionally use only persisted PR metadata. They provide a
  cheap baseline before external analyzers or model-backed review callbacks run.
  """

  @sensitive_patterns ~w(
    auth
    billing
    payment
    payments
    secret
    secrets
    token
    wallet
    signing
    webhook
    policy
    infra/prod
    config/prod
  )

  @test_patterns ~w(test spec __tests__)
  @config_patterns ~w(config .env dockerfile docker-compose terraform helm k8s)

  def analyze_pull_request(attrs) do
    files = Map.get(attrs, :files, [])
    paths = Enum.map(files, &path/1)
    changed_count = length(paths)
    sensitive_paths = Enum.filter(paths, &sensitive_path?/1)
    test_paths = Enum.filter(paths, &test_path?/1)
    config_paths = Enum.filter(paths, &config_path?/1)

    %{
      dimensions: %{
        "change_risk" => change_risk(changed_count, sensitive_paths, config_paths),
        "test_evidence" => test_evidence(paths, test_paths, sensitive_paths),
        "security" => security_score(sensitive_paths, test_paths, config_paths)
      },
      findings: findings(sensitive_paths, test_paths, config_paths),
      input_summary: %{
        changed_files: changed_count,
        sensitive_paths: sensitive_paths,
        test_paths: test_paths,
        config_paths: config_paths
      }
    }
  end

  def sensitive_path?(path), do: not test_path?(path) and contains_any?(path, @sensitive_patterns)
  def test_path?(path), do: contains_any?(path, @test_patterns)
  def config_path?(path), do: contains_any?(path, @config_patterns)

  defp path(%{path: path}) when is_binary(path), do: path
  defp path(%{"path" => path}) when is_binary(path), do: path
  defp path(path) when is_binary(path), do: path
  defp path(_file), do: ""

  defp change_risk(changed_count, sensitive_paths, config_paths) do
    92
    |> subtract(min(changed_count * 2, 30))
    |> subtract(length(sensitive_paths) * 10)
    |> subtract(length(config_paths) * 6)
    |> clamp()
  end

  defp test_evidence(paths, test_paths, sensitive_paths) do
    cond do
      paths == [] -> 50
      test_paths != [] and sensitive_paths == [] -> 88
      test_paths != [] -> 78
      sensitive_paths != [] -> 35
      true -> 62
    end
  end

  defp security_score(sensitive_paths, test_paths, config_paths) do
    90
    |> subtract(length(sensitive_paths) * 12)
    |> subtract(length(config_paths) * 6)
    |> maybe_add(test_paths != [], 8)
    |> clamp()
  end

  defp findings(sensitive_paths, test_paths, config_paths) do
    []
    |> maybe_finding(sensitive_paths != [], "high", "sensitive paths changed", sensitive_paths)
    |> maybe_finding(config_paths != [], "medium", "configuration paths changed", config_paths)
    |> maybe_finding(
      sensitive_paths != [] and test_paths == [],
      "high",
      "sensitive change has no test path evidence",
      sensitive_paths
    )
    |> Enum.reverse()
  end

  defp maybe_finding(findings, true, severity, message, paths) do
    [%{"severity" => severity, "message" => message, "paths" => paths} | findings]
  end

  defp maybe_finding(findings, false, _severity, _message, _paths), do: findings

  defp contains_any?(path, patterns) do
    normalized = String.downcase(path || "")
    Enum.any?(patterns, &String.contains?(normalized, &1))
  end

  defp subtract(score, value), do: score - value
  defp maybe_add(score, true, value), do: score + value
  defp maybe_add(score, false, _value), do: score
  defp clamp(score), do: score |> max(0) |> min(100)
end
