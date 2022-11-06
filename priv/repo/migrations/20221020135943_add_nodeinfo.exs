defmodule Pleroma.Repo.Migrations.AddNodeinfo do
  use Ecto.Migration

  def up do
    alter table(:instances) do
      add_if_not_exists(:nodeinfo, :map, default: %{})
      add_if_not_exists(:metadata_updated_at, :naive_datetime)
    end
  end

  def down do
    alter table(:instances) do
      remove_if_exists(:nodeinfo, :map)
      remove_if_exists(:metadata_updated_at, :naive_datetime)
    end
  end
end
