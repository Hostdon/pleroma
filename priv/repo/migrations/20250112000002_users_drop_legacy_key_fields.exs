defmodule Pleroma.Repo.Migrations.UsersDropLegacyKeyFields do
  use Ecto.Migration

  def up() do
    alter table(:users) do
      remove :keys, :text
      remove :public_key, :text
    end
  end

  def down() do
    # Using raw query since the "keys" field may not exist in the Elixir Ecto schema
    # causing issues when migrating data back and this requires column adds to be raw query too
    """
    ALTER TABLE public.users
    ADD COLUMN keys text,
    ADD COLUMN public_key text;
    """
    |> Pleroma.Repo.query!([], timeout: :infinity)

    """
    UPDATE public.users AS u
    SET keys = s.private_key
    FROM public.signing_keys AS s
    WHERE s.user_id = u.id AND
          u.local AND
          s.private_key IS NOT NULL;
    """
    |> Pleroma.Repo.query!([], timeout: :infinity)
  end
end
