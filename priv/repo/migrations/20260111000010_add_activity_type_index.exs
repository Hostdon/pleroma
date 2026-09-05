defmodule Pleroma.Repo.Migrations.AddActivityTypeIndex do
  use Ecto.Migration

  def change() do
    create_if_not_exists(
      index(
        :activities,
        ["(data->>'type')"],
        name: :activities_type_index
      )
    )
  end
end
