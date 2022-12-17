defmodule Pleroma.Repo.Migrations.AddPerUserPostExpiry do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:status_ttl_days, :integer, null: true)
    end
  end
end
