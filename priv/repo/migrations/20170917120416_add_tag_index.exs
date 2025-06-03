defmodule Pleroma.Repo.Migrations.AddTagIndex do
  use Ecto.Migration

  def change do
    create(
      index(:activities, ["(data #> '{\"object\",\"tag\"}')"],
        using: :gin,
        name: :activities_tags
      )
    )
  end
end
