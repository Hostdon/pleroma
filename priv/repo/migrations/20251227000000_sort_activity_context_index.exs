defmodule Pleroma.Repo.Migrations.SortActivityContextIndex do
  use Ecto.Migration

  # definied in 20170912114248_add_context_index.exs
  @old_idx index(
             :activities,
             ["(data->>'type')", "(data->>'context')"],
             name: :activities_context_index
           )

  # The index is only used in fetch_activities_for_context_query which
  # is always restricted to Creates and sorted by id (rev. chronologically)
  @new_idx index(
             :activities,
             ["(data->>'context')", "id DESC"],
             where: "(data->>'type') = 'Create'",
             name: :activities_context_index
           )

  def up() do
    drop_if_exists(@old_idx)
    create_if_not_exists(@new_idx)

    flush()

    # ensure planner immediately picks up new index for subsequent migrations
    execute("ANALYZE activities;")
  end

  def down() do
    drop_if_exists(@new_idx)
    create_if_not_exists(@old_idx)
  end
end
