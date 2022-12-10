defmodule Pleroma.Repo.Migrations.AddHasRequestSignatures do
  use Ecto.Migration

  def change do
    alter table(:instances) do
      add(:has_request_signatures, :boolean, default: false, null: false)
    end
  end
end
