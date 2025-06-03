defmodule Pleroma.Repo.Migrations.DropUnusedIndexes do
  use Ecto.Migration

  def up do
    # Leftovers from a late Pleroma migration (will not be restored on rollback)
    drop_i(:users, [:show_birthday], :users_show_birthday_index)

    drop_i(
      :users,
      ["date_part('month', birthday)", "date_part('day', birthday)"],
      :users_birthday_month_day_index
    )

    # Unused
    drop_i(:activities, ["(data->'cc')"], :activities_cc_index)
    drop_i(:activities, ["(data->'object'->>'inReplyTo')"], :activities_in_reply_to)
    drop_i(:activities, ["(data #> '{\"object\",\"likes\"}')"], :activities_likes)
    drop_i(:activities, ["(data->'to')"], :activities_to_index)

    drop_i(:objects, ["(data->'likes')"], :objects_likes)

    drop_i(:users, [:featured_address], :users_featured_address_index)
    drop_i(:users, [:following_address], :users_following_address_index)
    drop_i(:users, [:invisible], :users_invisible_index)
    drop_i(:users, [:last_status_at], :users_last_status_at_index)
    drop_i(:users, [:tags], :users_tags_index)

    drop_i(:apps, [:client_id, :client_secret], :apps_client_id_client_secret_index)
    drop_i(:apps, [:user_id], :apps_user_id_index)

    # Duplicate of primary key index (will not be restored on rollback)
    drop_i(
      :user_frontend_setting_profiles,
      [:user_id, :frontend_name, :profile_name],
      :user_frontend_setting_profiles_user_id_frontend_name_profile_name_index
    )
  end

  def down do
    create_i(:activities, ["(data->'cc')"], :activities_cc_index, :gin)
    create_i(:activities, ["(data->'object'->>'inReplyTo')"], :activities_in_reply_to)
    create_i(:activities, ["(data #> '{\"object\",\"likes\"}')"], :activities_likes, :gin)
    create_i(:activities, ["(data->'to')"], :activities_to_index, :gin)

    create_i(:objects, ["(data->'likes')"], :objects_likes, :gin)

    create_i(:users, [:featured_address], :users_featured_address_index)
    create_i(:users, [:following_address], :users_following_address_index)
    create_i(:users, [:invisible], :users_invisible_index)
    create_i(:users, [:last_status_at], :users_last_status_at_index)
    create_i(:users, [:tags], :users_tags_index, :gin)

    create_i(:apps, [:client_id, :client_secret], :apps_client_id_client_secret_index)
    create_i(:apps, [:user_id], :apps_user_id_index)
  end

  defp drop_i(table, fields, name) do
    drop_if_exists(index(table, fields, name: name))
  end

  defp create_i(table, fields, name, type \\ :btree) do
    create_if_not_exists(index(table, fields, name: name, using: type))
  end
end
