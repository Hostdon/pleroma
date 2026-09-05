defmodule Pleroma.Repo.Migrations.ReceiverWorkerIdKey do
  use Ecto.Migration

  def up() do
    # since we currently still support PostgreSQL 12 and 13, do NOT use the args['id'] snytax!
    """
    UPDATE public.oban_jobs
    SET args = jsonb_set(
      args,
      '{id}',
      to_jsonb(COALESCE(args#>>'{params,id}', id::text))
    )
    WHERE worker = 'Pleroma.Workers.ReceiverWorker';
    """
    |> Pleroma.Repo.query!([], timeout: :infinity)
  end

  def down() do
    # no action needed
    :ok
  end
end
