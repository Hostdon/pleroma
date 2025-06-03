defmodule Pleroma.Repo.Migrations.RemoveUserApEnabled do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove_if_exists(:ap_enabled, :boolean)
    end
  end

  def down do
    alter table(:users) do
      add_if_not_exists(:ap_enabled, :boolean, default: true, null: false)
    end
  end
end
