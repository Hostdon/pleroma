defmodule Pleroma.Activity.PrunerTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Activity.Pruner

  import Pleroma.Factory

  describe "prune_deletes" do
    test "it prunes old delete objects" do
      user = insert(:user)

      new_delete = insert(:delete_activity, type: "Delete", user: user)

      old_delete =
        insert(:delete_activity,
          type: "Delete",
          user: user,
          inserted_at: DateTime.utc_now() |> DateTime.add(-31 * 24, :hour)
        )

      Pruner.prune_deletes()
      assert Activity.get_by_id(new_delete.id)
      refute Activity.get_by_id(old_delete.id)
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
