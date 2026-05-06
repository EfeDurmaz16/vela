defmodule Vela.Evidence.Alarms do
  @moduledoc """
  Tamper alarm persistence for failed evidence verification.
  """

  alias Vela.Evidence.TamperAlarm
  alias Vela.Repo

  def record_tamper!(organization_id, repository_id, %{reason: reason} = error) do
    attrs = %{
      organization_id: organization_id,
      repository_id: repository_id,
      evidence_event_id: Map.get(error, :event_id),
      reason: to_string(reason),
      event_hash: Map.get(error, :event_hash),
      status: "open"
    }

    case existing_alarm(organization_id, attrs.event_hash, attrs.reason) do
      %TamperAlarm{} = alarm ->
        alarm

      nil ->
        case %TamperAlarm{} |> TamperAlarm.changeset(attrs) |> Repo.insert() do
          {:ok, alarm} ->
            alarm

          {:error, changeset} ->
            if unique_violation?(changeset) do
              existing_alarm(organization_id, attrs.event_hash, attrs.reason)
            else
              raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
            end
        end
    end
  end

  defp existing_alarm(organization_id, event_hash, reason) do
    Repo.get_by(TamperAlarm,
      organization_id: organization_id,
      event_hash: event_hash,
      reason: reason
    )
  end

  defp unique_violation?(changeset) do
    Enum.any?(changeset.errors, fn
      {_field, {_message, opts}} -> opts[:constraint] == :unique
    end)
  end
end
