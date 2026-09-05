defmodule Pleroma.Repo.Migrations.DropInstanceHasRequestSignatures do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      remove(:has_request_signatures, :boolean, default: false, null: false)
    end
  end
end
