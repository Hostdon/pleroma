defmodule Pleroma.Repo.Migrations.AddSigningKeyIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:signing_keys, [:user_id], name: :signing_keys_user_id_index))
  end
end
