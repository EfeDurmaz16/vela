defmodule Vela.Maestro.ReadinessScore do
  use Vela.Schema

  @verdicts ~w(ship wait block)
  @confidences ~w(low medium high)
  @dimension_keys ~w(
    repository_trust
    change_risk
    test_evidence
    security
    performance
    agent_provenance
    launch_readiness
  )

  schema "readiness_scores" do
    field :score, :integer
    field :verdict, :string
    field :confidence, :string
    field :dimensions, :map, default: %{}
    field :dimension_explanations, :map, default: %{}
    field :explanation, :string
    field :evidence_refs, {:array, :binary_id}, default: []
    field :input_refs, :map, default: %{}

    belongs_to :organization, Vela.Accounts.Organization
    belongs_to :repository, Vela.Forge.Repository
    belongs_to :change, Vela.Forge.Change
    belongs_to :analysis_run, Vela.Maestro.AnalysisRun

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def dimension_keys, do: @dimension_keys

  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :organization_id,
      :repository_id,
      :change_id,
      :analysis_run_id,
      :score,
      :verdict,
      :confidence,
      :dimensions,
      :dimension_explanations,
      :explanation,
      :evidence_refs,
      :input_refs
    ])
    |> validate_required([
      :organization_id,
      :repository_id,
      :score,
      :verdict,
      :confidence,
      :dimensions,
      :explanation
    ])
    |> Vela.Validation.validate_score(:score)
    |> Vela.Validation.validate_inclusion(:verdict, @verdicts)
    |> Vela.Validation.validate_inclusion(:confidence, @confidences)
    |> validate_dimensions()
    |> put_dimension_explanations()
    |> validate_dimension_explanations()
  end

  defp validate_dimensions(changeset) do
    validate_change(changeset, :dimensions, fn :dimensions, dimensions ->
      errors =
        Enum.flat_map(@dimension_keys, fn key ->
          value = Map.get(dimensions, key)

          cond do
            not is_integer(value) -> [{:dimensions, "#{key} is required"}]
            value < 0 or value > 100 -> [{:dimensions, "#{key} must be between 0 and 100"}]
            true -> []
          end
        end)

      errors
    end)
  end

  defp put_dimension_explanations(changeset) do
    case get_field(changeset, :dimension_explanations) do
      explanations when explanations in [nil, %{}] ->
        put_change(
          changeset,
          :dimension_explanations,
          default_dimension_explanations(get_field(changeset, :dimensions) || %{})
        )

      _explanations ->
        changeset
    end
  end

  defp default_dimension_explanations(dimensions) do
    Map.new(@dimension_keys, fn key ->
      score = Map.get(dimensions, key)
      {key, "#{humanize_dimension(key)} contributed #{score}/100 to the readiness verdict."}
    end)
  end

  defp humanize_dimension(key), do: key |> String.replace("_", " ") |> String.capitalize()

  defp validate_dimension_explanations(changeset) do
    verdict = get_field(changeset, :verdict)

    if verdict in ["wait", "block"] do
      explanations = get_field(changeset, :dimension_explanations) || %{}

      errors =
        Enum.flat_map(@dimension_keys, fn key ->
          explanation = Map.get(explanations, key)

          if is_binary(explanation) and String.length(String.trim(explanation)) >= 20 do
            []
          else
            [{:dimension_explanations, "#{key} explanation is required for #{verdict} verdict"}]
          end
        end)

      Enum.reduce(errors, changeset, fn {field, message}, acc ->
        add_error(acc, field, message)
      end)
    else
      changeset
    end
  end
end
