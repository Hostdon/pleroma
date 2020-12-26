defmodule Pleroma.Repo.Migrations.UserRawBio do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:raw_bio, :text)
    end
  end
end
