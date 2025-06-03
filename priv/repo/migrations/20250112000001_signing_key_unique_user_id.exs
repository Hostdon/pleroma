defmodule Pleroma.Repo.Migrations.SigningKeyUniqueUserId do
  use Ecto.Migration

  import Ecto.Query

  def up() do
    # If dupes exists for any local user we do NOT want to delete the genuine privkey alongside the fake.
    # Instead just filter out anything pertaining to local users, if dupes exists manual intervention
    # is required anyway and index creation will just fail later (check against legacy field in users table)
    dupes =
      Pleroma.User.SigningKey
      |> join(:inner, [s], u in Pleroma.User, on: s.user_id == u.id)
      |> group_by([s], s.user_id)
      |> having([], count() > 1)
      |> having([_s, u], not fragment("bool_or(?)", u.local))
      |> select([s], s.user_id)

    # Delete existing remote duplicates
    # they’ll be reinserted on the next user update
    # or proactively fetched when receiving a signature from it
    Pleroma.User.SigningKey
    |> where([s], s.user_id in subquery(dupes))
    |> Pleroma.Repo.delete_all()

    drop_if_exists(index(:signing_keys, [:user_id]))

    create_if_not_exists(
      index(:signing_keys, [:user_id], name: :signing_keys_user_id_index, unique: true)
    )
  end

  def down() do
    drop_if_exists(index(:signing_keys, [:user_id]))
    create_if_not_exists(index(:signing_keys, [:user_id], name: :signing_keys_user_id_index))
  end
end
