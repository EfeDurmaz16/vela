defmodule Vela.Pipelines do
  @moduledoc """
  BYO runner and pipeline metadata. Phase 0 stores seeded state only.
  """

  alias Vela.Pipelines.{PipelineJob, PipelineRun, Runner}
  alias Vela.Repo

  def create_runner(attrs), do: %Runner{} |> Runner.changeset(attrs) |> Repo.insert()

  def create_pipeline_run(attrs),
    do: %PipelineRun{} |> PipelineRun.changeset(attrs) |> Repo.insert()

  def create_pipeline_job(attrs),
    do: %PipelineJob{} |> PipelineJob.changeset(attrs) |> Repo.insert()
end
