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
end
