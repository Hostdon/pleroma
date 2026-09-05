defmodule Pleroma.Repo.Migrations.StoreOutboxAddress do
  use Ecto.Migration

  def change() do
    alter table("users") do
      add :outbox, :text
    end
  end
end
