defmodule Pleroma.Repo.Migrations.CreateSigningKeyTable do
  use Ecto.Migration

  def change do
    create table(:signing_keys, primary_key: false) do
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :key_id, :text, primary_key: true
      add :public_key, :text
      add :private_key, :text
      timestamps()
    end
  end
end
