defmodule Pleroma.Activity.PrunerTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Activity.Pruner

  import Pleroma.Factory

  describe "prune_transient_activities" do
    test "it prunes old transient activities" do
      user = insert(:user)
      old_time = DateTime.utc_now() |> DateTime.add(-31 * 24, :hour)

      new_delete = insert(:delete_activity, type: "Delete", user: user)

      old_delete =
        insert(:delete_activity,
          user: user,
          inserted_at: old_time
        )

      new_update = insert(:update_activity, type: "Update", user: user)

      old_update =
        insert(:update_activity,
          type: "Update",
          user: user,
          inserted_at: old_time
        )

      new_undo = insert(:undo_activity)

      old_undo = insert(:undo_activity, inserted_at: old_time)

      new_remove = insert(:remove_activity)

      old_remove = insert(:remove_activity, inserted_at: old_time)

      Pruner.prune_deletes()
      Pruner.prune_updates()
      Pruner.prune_undos()
      Pruner.prune_removes()

      assert Activity.get_by_id(new_delete.id)
      refute Activity.get_by_id(old_delete.id)

      assert Activity.get_by_id(new_update.id)
      refute Activity.get_by_id(old_update.id)

      assert Activity.get_by_id(new_undo.id)
      refute Activity.get_by_id(old_undo.id)

      assert Activity.get_by_id(new_remove.id)
      refute Activity.get_by_id(old_remove.id)
    end
  end

  describe "prune_stale_follow_requests" do
    test "it prunes old follow requests" do
      follower = insert(:user)
      followee = insert(:user)

      new_follow_request =
        insert(
          :follow_activity,
          follower: follower,
          followed: followee,
          state: "reject"
        )

      old_not_rejected_request =
        insert(:follow_activity,
          follower: follower,
          followed: followee,
          state: "pending",
          inserted_at: DateTime.utc_now() |> DateTime.add(-31 * 24, :hour)
        )

      old_follow_request =
        insert(:follow_activity,
          follower: follower,
          followed: followee,
          inserted_at: DateTime.utc_now() |> DateTime.add(-31 * 24, :hour),
          state: "reject"
        )

      Pruner.prune_stale_follow_requests()
      assert Activity.get_by_id(new_follow_request.id)
      assert Activity.get_by_id(old_not_rejected_request.id)
      refute Activity.get_by_id(old_follow_request.id)
    end
  end
end
