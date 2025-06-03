defmodule Pleroma.Repo.Migrations.AddSecondObjectIndexToActivty do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:activities, ["(data->'object'->>'id')", "(data->>'type')"],
        name: :activities_create_objects_index
      )
    )

    create(
      index(:activities, ["(coalesce(data->'object'->>'id', data->>'object'))"],
        name: :activities_create_objects_index
      )
    )
  end
end
