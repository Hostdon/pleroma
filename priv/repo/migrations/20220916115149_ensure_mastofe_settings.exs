defmodule Pleroma.Repo.Migrations.EnsureMastofeSettings do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists(:mastofe_settings, :map)
    end
  end

  def down do
    alter table(:users) do
      remove_if_exists(:mastofe_settings, :map)
    end
  end
end
