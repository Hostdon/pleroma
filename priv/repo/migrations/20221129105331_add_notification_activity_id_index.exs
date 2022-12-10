defmodule Pleroma.Repo.Migrations.AddNotificationActivityIdIndex do
  use Ecto.Migration

  def change do
    create(index(:notifications, [:activity_id]))
  end
end
