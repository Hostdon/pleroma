defmodule Pleroma.Repo.Migrations.ConversationParticipationLastStatusId do
  use Ecto.Migration

  # definied in 20190410152859_add_participation_updated_at_index.exs
  @old_sort_idx index(:conversation_participations, ["updated_at desc"])

  # requires new column to be created and filled first
  # (the column i not nullable, but ordering is done by pagination helper which always uses NULLS LAST
  #  and currently postgres isn't smart enough to use a simple DESC index anyway)
  @new_sort_idx index(:conversation_participations, [:user_id, "last_bump DESC NULLS LAST"])

  def up() do
    drop_if_exists(@old_sort_idx)

    # create new col, temporarily nullable
    # Do NOT use foreign-key constraint, we don't care if the message is deleted
    # nor do we use it for joins. This is just a funny timestamp
    alter table(:conversation_participations) do
      add :last_bump, :uuid, null: true
    end

    flush()

    # fill in data
    execute """
      UPDATE conversation_participations AS p
      SET last_bump = (
        SELECT a.id
        FROM activities AS a
        WHERE a.data->>'context' = c.ap_id AND
              a.data->>'type' = 'Create' AND
              (u.ap_id = ANY(a.recipients) OR u.ap_id = a.actor) AND
              activity_visibility(a.actor, a.recipients, a.data) = 'direct'
        ORDER BY a.id DESC
        LIMIT 1
      )
      FROM conversation_participations AS p2
           JOIN users AS u ON p2.user_id = u.id
           JOIN conversations AS c ON p2.conversation_id = c.id
      WHERE p2.id = p.id;
    """

    # delete empty conversations if any
    execute """
      DELETE FROM conversation_participations
      WHERE last_bump IS NULL;
    """

    execute """
      DELETE FROM conversations AS c
      WHERE NOT EXISTS (
        SELECT 1
        FROM conversation_participations AS p
        WHERE p.conversation_id = c.id
      );
    """

    flush()

    # set non-nullable
    alter table(:conversation_participations) do
      modify :last_bump, :uuid, null: false
    end

    # indexes
    create_if_not_exists(@new_sort_idx)
  end

  def down() do
    # new indexes automatically dropped alongside column
    alter table(:conversation_participations) do
      remove :last_bump
    end

    create_if_not_exists(@old_sort_idx)
  end
end
