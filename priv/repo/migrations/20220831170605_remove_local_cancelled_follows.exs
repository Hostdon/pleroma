defmodule Pleroma.Repo.Migrations.RemoveLocalCancelledFollows do
  use Ecto.Migration

  def up do
    statement = """
    DELETE FROM
        activities
    WHERE
        (data->>'type') = 'Follow'
    AND
        (data->>'state') = 'cancelled'
    AND
        local = true;
    """

    execute(statement)
  end

  def down do
    :ok
  end
end
