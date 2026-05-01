defmodule Vela.Pipelines.PipelineJob do
  use Vela.Schema

  schema "pipeline_jobs" do
    field :name, :string
    field :command, :string
    field :sandbox_config, :map, default: %{}
    field :logs_ref, :string
    field :artifacts_ref, :string
    field :status, :string

    belongs_to :pipeline_run, Vela.Pipelines.PipelineRun

    timestamps(type: :utc_datetime)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :pipeline_run_id,
      :name,
      :command,
      :sandbox_config,
      :logs_ref,
      :artifacts_ref,
      :status
    ])
    |> validate_required([:pipeline_run_id, :name, :command, :status])
  end
end
