defmodule Pleroma.Repo.Migrations.AddContextIndex do
  use Ecto.Migration

  def change do
    create(
      index(:activities, ["(data->>'type')", "(data->>'context')"],
        name: :activities_context_index
      )
    )
  end
end
