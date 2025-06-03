defmodule Pleroma.Repo.Migrations.MoveSigningKeys do
  use Ecto.Migration
  alias Pleroma.User
  alias Pleroma.Repo
  import Ecto.Query

  def up do
    # we do not handle remote users here!
    # because we want to store a key id -> user id mapping, and we don't
    # currently store key ids for remote users...
    # Also this MUST use select, else the migration will fail in future installs with new user fields!
    from(u in Pleroma.User,
      where: u.local == true,
      select: {u.id, fragment("?.keys", u), u.ap_id}
    )
    |> Repo.stream(timeout: :infinity)
    |> Enum.each(fn
      {user_id, private_key, ap_id} ->
        IO.puts("Migrating user #{user_id}")
        # we can precompute the public key here...
        # we do use it on every user view which makes it a bit of a dos attack vector
        # so we should probably cache it
        {:ok, public_key} = User.SigningKey.private_pem_to_public_pem(private_key)

        key = %User.SigningKey{
          user_id: user_id,
          public_key: public_key,
          key_id: User.SigningKey.local_key_id(ap_id),
          private_key: private_key
        }

        {:ok, _} = Repo.insert(key)
    end)
  end

  # no need to rollback
  def down, do: :ok
end
