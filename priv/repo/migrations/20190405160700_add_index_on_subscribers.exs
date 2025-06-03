defmodule Pleroma.Repo.Migrations.AddIndexOnSubscribers do
  use Ecto.Migration

  def change do
    create(
      index(:users, ["(info->'subscribers')"],
        name: :users_subscribers_index,
        using: :gin
      )
    )
  end
end
