defmodule Pleroma.Repo.Migrations.RestrictEligibleUserIndexes do
  use Ecto.Migration

  @old_indexes [
    index(:users, [:email], unique: true),
    index(:users, [:is_admin]),
    index(:users, [:is_moderator]),
    index(:users, [:is_suggested]),
    index(:users, [:last_active_at])
  ]

  @new_indexes [
    # We use this to send out emails to local users, i.e. we only care about
    # _local_ users who also set an email to begin with
    # (and to ensure no two local users claim the same email address;
    #  though if we somehow get an email for a remote user, we don't care about collisions)
    index(:users, [:email], unique: true, where: "email IS NOT NULL AND local"),

    # Just used to quickly retrieve all suggested useres
    # (this perhaps should have been a separate table to begin with).
    # This MUST use BTREE, a HASH index will not be used when querying all suggested users!
    index(:users, [:id],
      where: "is_suggested",
      using: :btree,
      name: :users_where_suggested_index
    ),

    # Only _local_ users can be admins or moderators and in practice
    # this criteria is only used to query for a "true" setting.
    # According to EXPLAIN, restricting just by the "true" state even performs _slightly_ better
    # and requires less to keep in mind when contructing queries
    index(:users, [:is_admin], where: "is_admin"),
    index(:users, [:is_moderator], where: "is_moderator"),

    # The following is only set and used for _local_ users
    index(:users, [:last_active_at], where: "local")
  ]

  defp drop_all(indexes) do
    for idx <- indexes do
      drop_if_exists(idx)
    end
  end

  defp create_all(indexes) do
    for idx <- indexes do
      create_if_not_exists(idx)
    end
  end

  def up() do
    drop_all(@old_indexes)
    create_all(@new_indexes)
  end

  def down() do
    drop_all(@new_indexes)
    create_all(@old_indexes)
  end
end
