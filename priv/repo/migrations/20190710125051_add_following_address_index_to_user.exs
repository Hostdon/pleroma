defmodule Pleroma.Repo.Migrations.AddFollowingAddressIndexToUser do
  use Ecto.Migration

  def change do
    create(index(:users, [:following_address]))
  end
end
