defmodule Mix.Tasks.Vela.Smoke do
  @moduledoc """
  Runs non-destructive live credential smoke checks.
  """

  use Mix.Task

  alias Vela.Smoke.CredentialHarness

  @shortdoc "Runs Vela provider credential smoke checks"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [
          check: :keep,
          checks: :string
        ]
      )

    if invalid != [] do
      Mix.raise("invalid vela.smoke option(s): #{inspect(invalid)}")
    end

    results =
      [checks: checks(opts)]
      |> CredentialHarness.run()

    results
    |> CredentialHarness.format_results()
    |> Enum.each(fn line -> Mix.shell().info(line) end)

    if CredentialHarness.exit_status(results) != 0 do
      Mix.raise("one or more configured Vela smoke checks failed")
    end
  end

  defp checks(opts) do
    opts
    |> Keyword.get_values(:check)
    |> Kernel.++(split_checks(Keyword.get(opts, :checks)))
    |> case do
      [] -> [:workos, :github, :s3, :webhooks]
      values -> Enum.map(values, &parse_check!/1)
    end
  end

  defp split_checks(nil), do: []

  defp split_checks(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp parse_check!(value) when value in [:workos, :github, :s3, :webhooks], do: value

  defp parse_check!(value) when is_binary(value) do
    case String.downcase(value) do
      "workos" -> :workos
      "github" -> :github
      "s3" -> :s3
      "webhooks" -> :webhooks
      other -> Mix.raise("unknown vela.smoke check: #{other}")
    end
  end
end
