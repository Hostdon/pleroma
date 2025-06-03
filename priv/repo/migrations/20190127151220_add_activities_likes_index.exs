defmodule Pleroma.Repo.Migrations.AddActivitiesLikesIndex do
  use Ecto.Migration

  def change do
    create(
      index(:activities, ["((data #> '{\"object\",\"likes\"}'))"],
        name: :activities_likes,
        using: :gin
      )
    )
  end
end
