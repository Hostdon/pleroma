defmodule Pleroma.Repo.Migrations.DropPlainUsersNicknameIndex do
  use Ecto.Migration

  def change() do
    # redundant with the explicitly case-folded index
    drop_if_exists(unique_index(:users, [:nickname], name: :users_nickname_index))
  end
end
