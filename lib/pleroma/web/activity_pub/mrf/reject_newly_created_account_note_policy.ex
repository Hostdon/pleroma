defmodule Pleroma.Web.ActivityPub.MRF.RejectNewlyCreatedAccountNotesPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.User

  @moduledoc """
  Rejects notes from accounts that were created below a certain threshold of time ago
  """
  @impl true
  def filter(
        %{
          "type" => type,
          "actor" => actor
        } = activity
      )
      when type in ["Note", "Create"] do
    min_age = Pleroma.Config.get([:mrf_reject_newly_created_account_notes, :age])

    with %User{local: false} = user <- Pleroma.User.get_cached_by_ap_id(actor),
         true <- Timex.diff(Timex.now(), user.inserted_at, :seconds) < min_age do
      {:reject, "[RejectNewlyCreatedAccountNotesPolicy] Account created too recently"}
    else
      _ -> {:ok, activity}
    end
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_reject_newly_created_account_notes,
      related_policy: "Pleroma.Web.ActivityPub.MRF.RejectNewlyCreatedAccountNotesPolicy",
      label: "MRF Reject New Accounts",
      description: "Reject notes from accounts created too recently",
      children: [
        %{
          key: :age,
          type: :integer,
          description: "Time below which to reject (in seconds)",
          suggestions: [86_400]
        }
      ]
    }
  end
end
