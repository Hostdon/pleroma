defmodule Pleroma.Repo.Migrations.AddUnfollowedDmRestrictions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:accepts_direct_messages_from, :string, default: "everybody")
    end
  end
end
