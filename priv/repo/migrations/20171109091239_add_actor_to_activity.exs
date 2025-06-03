defmodule Pleroma.Repo.Migrations.AddActorToActivity do
  use Ecto.Migration

  def up do
    alter table(:activities) do
      add(:actor, :string)
    end

    create(index(:activities, [:actor, "id DESC NULLS LAST"]))
  end

  def down do
    drop_if_exists(index(:activities, [:actor, "id DESC NULLS LAST"]))

    alter table(:activities) do
      remove(:actor)
    end
  end
end
