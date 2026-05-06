defmodule Vela.LocalAnalyzersTest do
  use ExUnit.Case, async: true

  alias Vela.Maestro.LocalAnalyzers

  test "flags sensitive file changes without matching test evidence" do
    result =
      LocalAnalyzers.analyze_pull_request(%{
        files: [
          %{path: "apps/web/lib/vela/auth/token.ex"},
          %{path: "apps/web/config/prod.exs"}
        ]
      })

    assert result.dimensions["security"] < 75
    assert result.dimensions["test_evidence"] == 35

    assert result.input_summary.sensitive_paths == [
             "apps/web/lib/vela/auth/token.ex",
             "apps/web/config/prod.exs"
           ]

    assert result.input_summary.config_paths == ["apps/web/config/prod.exs"]

    assert Enum.any?(
             result.findings,
             &(&1["message"] == "sensitive change has no test path evidence")
           )
  end

  test "credits test evidence for sensitive changes" do
    result =
      LocalAnalyzers.analyze_pull_request(%{
        files: [
          "apps/web/lib/vela/policy.ex",
          "apps/web/test/vela/policy_test.exs"
        ]
      })

    assert result.dimensions["test_evidence"] == 78
    assert result.dimensions["security"] >= 80

    refute Enum.any?(
             result.findings,
             &(&1["message"] == "sensitive change has no test path evidence")
           )
  end

  test "keeps ordinary application changes lower risk" do
    result =
      LocalAnalyzers.analyze_pull_request(%{
        files: [
          %{"path" => "apps/web/lib/vela_web/live/app_live.ex"},
          %{"path" => "apps/web/test/vela_web/live/app_live_test.exs"}
        ]
      })

    assert result.dimensions["change_risk"] >= 80
    assert result.dimensions["test_evidence"] == 88
    assert result.findings == []
  end
end
