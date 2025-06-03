defmodule Pleroma.Repo.Migrations.ModifyActivityIndex do
  use Ecto.Migration

  def change do
    create(index(:activities, ["id desc nulls last", "local"]))
    drop_if_exists(index(:activities, ["id desc nulls last"]))
  end
end
