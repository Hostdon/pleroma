defmodule Pleroma.Repo.Migrations.DeleteeRemoteParticipations do
  use Ecto.Migration

  def up() do
    execute """
    DELETE FROM conversation_participations AS p
    USING users AS u
    WHERE p.user_id = u.id
      AND NOT u.local
    ;
    """
  end

  def down() do
    # not reversible, but never made sense
    # and the only thing "relying" on it
    # was broken and non-sensical either way
    :ok
  end
end
