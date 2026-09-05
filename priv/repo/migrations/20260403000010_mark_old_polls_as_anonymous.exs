defmodule Pleroma.Repo.Migrations.MarkOldPollsAsAnonymous do
  use Ecto.Migration

  def up() do
    # objects does not have a local flag.
    # Pleroma.Web.Endpoint available during migrations, meaning we can't reliably
    # get the local base url to test against instead.
    # Thus we mustjoin either with the users or activity table to determine localality.
    # The existing objects_actor_type' index is a perfect fit for this query and joining with users.
    """
    UPDATE objects AS o
    SET data = jsonb_set(data, '{nonAnonymous}', to_jsonb(false), true)
    FROM users AS u
    WHERE
      o.data->>'type' = 'Question' AND
      o.data->>'actor' = u.ap_id AND
      u.local
    ;
    """
    |> Pleroma.Repo.query!([], timeout: :infinity)
  end

  # No need to revert
  def down(), do: :ok
end
