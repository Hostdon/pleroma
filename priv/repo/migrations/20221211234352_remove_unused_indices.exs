defmodule Pleroma.Repo.Migrations.RemoveUnusedIndices do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:activities, ["(data->>'actor')", "inserted_at desc"], name: :activities_actor_index)
    )

    drop_if_exists(index(:objects, ["(data->'tag')"], using: :gin, name: :objects_tags))
  end
end
