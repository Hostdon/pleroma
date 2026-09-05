defmodule Pleroma.Repo.Migrations.AddDefaultTextSearchConfig do
  use Ecto.Migration

  def change do
    execute("DO $$
    BEGIN
    execute 'ALTER DATABASE \"'||current_database()||'\" SET default_text_search_config = ''simple'' ';
    END
    $$;")
  end
end
