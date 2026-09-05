defmodule Pleroma.Repo.Migrations.AddExclusiveToLists do
  use Ecto.Migration

  def change do
    alter table(:lists) do
      add(:exclusive, :boolean, default: false)
    end
  end
end
