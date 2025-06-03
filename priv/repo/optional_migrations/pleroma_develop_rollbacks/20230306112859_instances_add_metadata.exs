defmodule Pleroma.Repo.Migrations.InstancesAddMetadata do
  use Ecto.Migration

  def down do
    alter table(:instances) do
      remove_if_exists(:metadata, :map)
    end
  end

  def up do
    alter table(:instances) do
      add_if_not_exists(:metadata, :map)
    end
  end
end
