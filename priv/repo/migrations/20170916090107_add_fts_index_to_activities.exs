defmodule Pleroma.Repo.Migrations.AddFTSIndexToActivities do
  use Ecto.Migration

  def change do
    create(
      index(:activities, ["(to_tsvector('simple', data->'object'->>'content'))"],
        using: :gin,
        name: :activities_fts
      )
    )
  end
end
