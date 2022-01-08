defmodule Pleroma.Repo.Migrations.AddMastofeSettings do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:mastofe_settings, :map)
    end
  end
end
