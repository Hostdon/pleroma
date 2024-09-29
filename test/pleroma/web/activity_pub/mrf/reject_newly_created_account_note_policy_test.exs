defmodule Pleroma.Web.ActivityPub.MRF.RejectNewlyCreatedAccountNotesPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.RejectNewlyCreatedAccountNotesPolicy

  describe "reject notes from new accounts" do
    test "rejects notes from accounts created more recently than `age`" do
      clear_config([:mrf_reject_newly_created_account_notes, :age], 86_400)
      sender = insert(:user, %{inserted_at: Timex.now(), local: false})

      message = %{
        "actor" => sender.ap_id,
        "type" => "Create"
      }

      assert {:reject, _} = RejectNewlyCreatedAccountNotesPolicy.filter(message)
    end

    test "does not reject notes from accounts created longer ago" do
      clear_config([:mrf_reject_newly_created_account_notes, :age], 86_400)
      a_day_ago = Timex.shift(Timex.now(), days: -1)
      sender = insert(:user, %{inserted_at: a_day_ago, local: false})

      message = %{
        "actor" => sender.ap_id,
        "type" => "Create"
      }

      assert {:ok, _} = RejectNewlyCreatedAccountNotesPolicy.filter(message)
    end

    test "does not affect local users" do
      clear_config([:mrf_reject_newly_created_account_notes, :age], 86_400)
      sender = insert(:user, %{inserted_at: Timex.now(), local: true})

      message = %{
        "actor" => sender.ap_id,
        "type" => "Create"
      }

      assert {:ok, _} = RejectNewlyCreatedAccountNotesPolicy.filter(message)
    end
  end
end
