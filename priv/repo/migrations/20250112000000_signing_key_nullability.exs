defmodule Pleroma.Repo.Migrations.SigningKeyNullability do
  use Ecto.Migration

  import Ecto.Query

  def up() do
    # Delete existing NULL entries; they are useless
    Pleroma.User.SigningKey
    |> where([s], is_nil(s.user_id) or is_nil(s.public_key))
    |> Pleroma.Repo.delete_all()

    alter table(:signing_keys) do
      modify :user_id, :uuid, null: false
      modify :public_key, :text, null: false
    end
  end

  def down() do
    alter table(:signing_keys) do
      modify :user_id, :uuid, null: true
      modify :public_key, :text, null: true
    end
  end
end
