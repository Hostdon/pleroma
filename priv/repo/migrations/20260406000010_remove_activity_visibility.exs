defmodule Pleroma.Repo.Migrations.RemoveActivityVisibility do
  use Ecto.Migration

  # introduced 20220506175506_add_index_hotspots.exs for the activity_visibility function
  # renamed to nudge postgres to restore before the activity_visibility index depending on it
  @idx_fa index(:users, [:ap_id, "COALESCE(follower_address, '')"],
            name: :aa_users_ap_id_COALESCE_follower_address_index
          )

  # introduced with activity_visibility function and last updated in 20190204200237_add_correct_dm_index.exs
  @idx_av index(
            :activities,
            ["activity_visibility(actor, recipients, data)", "id DESC NULLS LAST"],
            name: :activities_visibility_index,
            where: "data->>'type' = 'Create'"
          )

  def up() do
    drop_if_exists(@idx_av)

    execute(
      "DROP FUNCTION IF EXISTS activity_visibility(actor varchar, recipients varchar[], data jsonb)"
    )

    drop_if_exists(@idx_fa)
  end

  def down() do
    create_if_not_exists(@idx_fa)

    # function definition
    # copied from 20190124131141_update_activity_visibility_again.exs

    """
    create or replace function activity_visibility(actor varchar, recipients varchar[], data jsonb) returns varchar as $$
    DECLARE
      fa varchar;
      public varchar := 'https://www.w3.org/ns/activitystreams#Public';
    BEGIN
      SELECT COALESCE(users.follower_address, '') into fa from public.users where users.ap_id = actor;

      IF data->'to' ? public THEN
        RETURN 'public';
      ELSIF data->'cc' ? public THEN
        RETURN 'unlisted';
      ELSIF ARRAY[fa] && recipients THEN
        RETURN 'private';
      ELSIF not(ARRAY[fa, public] && recipients) THEN
        RETURN 'direct';
      ELSE
        RETURN 'unknown';
      END IF;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE SECURITY DEFINER;
    """
    |> execute()

    create_if_not_exists(@idx_av)
  end
end
