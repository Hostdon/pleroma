defmodule Pleroma.Repo.Migrations.AddFollowingRelationshipsFollowingIdIndex do
  use Ecto.Migration

  # [:follower_index] index is useless because of [:follower_id, :following_id] index
  # [:following_id] index makes sense because of user's followers-targeted queries
  def change do
    drop_if_exists(index(:following_relationships, [:follower_id]))

    create_if_not_exists(index(:following_relationships, [:following_id]))
  end
end
