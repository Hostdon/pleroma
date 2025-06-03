defmodule Pleroma.Repo.Migrations.AddObjectActorIndex do
  use Ecto.Migration

  def change do
    create(index(:objects, ["(data->>'actor')", "(data->>'type')"], name: :objects_actor_type))
  end
end
