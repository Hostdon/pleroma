defmodule Pleroma.Repo.Migrations.SanitizePollsVotersCount do
  use Ecto.Migration

  def up() do
    """
    UPDATE objects
    SET data = jsonb_set(
      data,
      '{votersCount}'::text[],
      to_jsonb(
        CASE
          WHEN jsonb_typeof(data->'voters') = 'array' THEN jsonb_array_length(data->'voters')
          ELSE 0
        END
      ),
      TRUE
    )
    WHERE data->>'type' = 'Question' AND
      COALESCE(jsonb_typeof(data->'votersCount'), 'NULL') <> 'number'
    ;
    """
    |> execute()
  end

  def down() do
    # no need to revert
    :ok
  end
end
