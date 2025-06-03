defmodule Pleroma.Repo.Migrations.AddSortIndexToActivities do
  use Ecto.Migration

  def change do
    create(index(:activities, ["id desc nulls last"]))
  end
end
