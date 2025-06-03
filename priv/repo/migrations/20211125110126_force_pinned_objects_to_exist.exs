defmodule Pleroma.Repo.Migrations.ForcePinnedObjectsToExist do
  use Ecto.Migration

  def up do
    execute("UPDATE users SET pinned_objects = '{}' WHERE pinned_objects IS NULL")

    alter table("users") do
      modify(:pinned_objects, :map, null: false, default: %{})
    end
  end

  def down do
    alter table("users") do
      modify(:pinned_objects, :map, null: true, default: nil)
    end

    execute("UPDATE users SET pinned_objects = NULL WHERE pinned_objects = '{}'")
  end
end
