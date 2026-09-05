defmodule Pleroma.Repo.Migrations.RemoveListsApId do
  use Ecto.Migration

  def up() do
    alter table(:lists) do
      remove_if_exists(:ap_id, :text)
    end
  end

  def down() do
    alter table(:lists) do
      # yes, this was nullable before too
      add_if_not_exists(:ap_id, :text)
    end

    # Restore previous AP ID schema
    """
    UPDATE lists AS l
    SET ap_id = u.ap_id || '/lists/' || l.id::text
    FROM users AS u
    WHERE u.id = l.user_id;
    """
    |> Pleroma.Repo.query!([], timeout: :infinity)
  end
end
