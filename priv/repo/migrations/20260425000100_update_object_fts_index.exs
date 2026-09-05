defmodule Pleroma.Repo.Migrations.UpdateObjectFTSIndex do
  use Ecto.Migration

  # copied from 20190501125843_add_fts_index_to_objects
  # but with parametrised current search config
  defmacro old_index(search_config) do
    quote do
      index(:objects, ["(to_tsvector('#{unquote(search_config)}'::regconfig, data->>'content'))"],
        using: :gin,
        name: :objects_fts
      )
    end
  end

  defmacro new_index(search_config) do
    quote do
      index(
        :objects,
        [
          """
          (to_tsvector(
            '#{unquote(search_config)}'::regconfig,
            COALESCE(data->>'summary', '') || ' ' || (data->>'content')
          ))
          """
        ],
        using: :gin,
        name: :objects_fts
      )
    end
  end

  def change() do
    %{rows: [[tsc]]} =
      Pleroma.Repo.query!("select current_setting('default_text_search_config')::regconfig;")

    drop_if_exists(old_index(tsc))
    create_if_not_exists(new_index(tsc))
  end
end
