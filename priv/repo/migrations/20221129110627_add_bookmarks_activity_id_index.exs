defmodule Pleroma.Repo.Migrations.AddBookmarksActivityIdIndex do
  use Ecto.Migration

  def change do
    create(index(:bookmarks, [:activity_id]))
  end
end
