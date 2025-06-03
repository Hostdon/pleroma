# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoteUserCountEstimateFunction do
  use Ecto.Migration

  @function_name "estimate_remote_user_count"

  def up() do
    # yep, this EXPLAIN (ab)use is blessed by the PostgreSQL wiki:
    #   https://wiki.postgresql.org/wiki/Count_estimate
    """
    CREATE OR REPLACE FUNCTION #{@function_name}()
    RETURNS integer
    LANGUAGE plpgsql AS $$
      DECLARE plan jsonb;
      BEGIN
        EXECUTE '
          EXPLAIN (FORMAT JSON)
          SELECT *
          FROM public.users
          WHERE local = false AND
                is_active = true AND
                invisible = false AND
                nickname IS NOT NULL;
        ' INTO plan;
        RETURN plan->0->'Plan'->'Plan Rows';
      END;
    $$;
    """
    |> execute()
  end

  def down() do
    execute("DROP FUNCTION IF EXISTS #{@function_name}()")
  end
end
