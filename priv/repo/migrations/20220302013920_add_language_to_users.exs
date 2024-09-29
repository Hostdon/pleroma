defmodule Pleroma.Repo.Migrations.AddLanguageToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists(:language, :string)
    end
  end

  def down do
    alter table(:users) do
      remove_if_exists(:language, :string)
    end
  end
end
