defmodule Pleroma.Repo.Migrations.UpgradeObanToV11 do
  use Ecto.Migration

  def up do
    execute("UPDATE oban_jobs SET priority = 0 WHERE priority IS NULL;")
    Oban.Migrations.up(version: 11)
  end

  def down, do: Oban.Migrations.down(version: 11)
end
