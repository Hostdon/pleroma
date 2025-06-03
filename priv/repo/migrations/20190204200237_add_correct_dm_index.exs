defmodule Pleroma.Repo.Migrations.AddCorrectDMIndex do
  use Ecto.Migration

  def up do
    drop_if_exists(
      index(:activities, ["activity_visibility(actor, recipients, data)"],
        name: :activities_visibility_index
      )
    )

    create(
      index(:activities, ["activity_visibility(actor, recipients, data)", "id DESC NULLS LAST"],
        name: :activities_visibility_index,
        where: "data->>'type' = 'Create'"
      )
    )
  end

  def down do
    drop_if_exists(
      index(:activities, ["activity_visibility(actor, recipients, data)", "id DESC"],
        name: :activities_visibility_index,
        where: "data->>'type' = 'Create'"
      )
    )
  end
end
