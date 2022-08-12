defmodule Pleroma.Repo.Migrations.RemoveNullObjects do
  use Ecto.Migration

  def up do
    statement = """
    DELETE FROM objects
    WHERE (data->>'type') is null;
    """

    execute(statement)
  end

  def down, do: :ok
end
