defmodule Pleroma.Repo.Migrations.AddFollowerAddressIndexToUsers do
  use Ecto.Migration

  def change do
    create(index(:users, [:follower_address]))
    create(index(:users, [:following], using: :gin))
  end
end
