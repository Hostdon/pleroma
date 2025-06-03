defmodule Pleroma.Repo.Migrations.CreateApidHostExtractionIndex do
  use Ecto.Migration

  def change do
    create(index(:activities, ["(split_part(actor, '/', 3))"], name: :activities_hosts))
  end
end
