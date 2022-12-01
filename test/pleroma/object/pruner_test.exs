defmodule Pleroma.Object.PrunerTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Delivery
  alias Pleroma.Object
  alias Pleroma.Object.Pruner

  import Pleroma.Factory

  describe "prune_deletes" do
    test "it prunes old delete objects" do
      new_tombstone = insert(:tombstone)

      old_tombstone =
        insert(:tombstone,
          inserted_at: DateTime.utc_now() |> DateTime.add(-31 * 24, :hour)
        )

      Pruner.prune_tombstones()
      assert Object.get_by_id(new_tombstone.id)
      refute Object.get_by_id(old_tombstone.id)
    end
  end

  describe "prune_tombstoned_deliveries" do
    test "it prunes old tombstone deliveries" do
      user = insert(:user)

      tombstone = insert(:tombstone)
      tombstoned = insert(:delivery, object: tombstone, user: user)

      note = insert(:note)
      not_tombstoned = insert(:delivery, object: note, user: user)

      Pruner.prune_tombstoned_deliveries()

      refute Repo.get(Delivery, tombstoned.id)
      assert Repo.get(Delivery, not_tombstoned.id)
    end
  end
end
