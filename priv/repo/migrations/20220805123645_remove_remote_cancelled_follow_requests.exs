defmodule Pleroma.Repo.Migrations.RemoveRemoteCancelledFollowRequests do
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
        local = false;
    """

    execute(statement)

    statement = """
    DELETE FROM
        activities
    WHERE
        (data->>'type') = 'Undo'
    AND
        (data->'object'->>'type') = 'Follow'
    AND
        local = false;
    """

    execute(statement)
  end

  def down do
    :ok
  end
end
