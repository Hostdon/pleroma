defmodule Pleroma.Repo.Migrations.AddFtsIndexToObjectsTwo do
  use Ecto.Migration

  defmacro gin_index(search_config) do
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

  def up do
    execute("create extension if not exists rum")

    %{rows: [[tsc]]} =
      Pleroma.Repo.query!("select current_setting('default_text_search_config')::regconfig;")

    drop_if_exists(gin_index(tsc))

    alter table(:objects) do
      add(:fts_content, :tsvector)
    end

    execute("CREATE FUNCTION objects_fts_update() RETURNS trigger AS $$
    begin
    new.fts_content := to_tsvector(COALESCE(new.data->>'summary', '') || ' ' || (new.data->>'content'));
    return new;
    end
    $$ LANGUAGE plpgsql")

    execute(
      "create index if not exists objects_fts on objects using RUM (fts_content rum_tsvector_addon_ops, inserted_at) with (attach = 'inserted_at', to = 'fts_content');"
    )

    execute("CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON objects
    FOR EACH ROW EXECUTE PROCEDURE objects_fts_update()")

    execute("UPDATE objects SET updated_at = NOW()")
  end

  def down do
    execute("drop index if exists objects_fts")
    execute("drop trigger if exists tsvectorupdate on objects")
    execute("drop function if exists objects_fts_update()")

    alter table(:objects) do
      remove(:fts_content, :tsvector)
    end

    %{rows: [[tsc]]} =
      Pleroma.Repo.query!("select current_setting('default_text_search_config')::regconfig;")

    create_if_not_exists(gin_index(tsc))
  end
end
