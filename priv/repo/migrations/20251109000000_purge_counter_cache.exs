defmodule Pleroma.Repo.Migrations.PurgeCounterCache do
  use Ecto.Migration

  @function_name "update_status_visibility_counter_cache"
  @trigger_name "status_visibility_counter_cache_trigger"
  @table_name "counter_cache"

  def up() do
    execute("DROP TRIGGER IF EXISTS " <> @trigger_name <> " ON activities;")
    execute("DROP FUNCTION IF EXISTS " <> @function_name <> ";")

    # automatically drops indices
    drop table(@table_name)
  end

  def down() do
    create_if_not_exists table(:counter_cache) do
      add(:instance, :string, null: false)
      add(:direct, :bigint, null: false, default: 0)
      add(:private, :bigint, null: false, default: 0)
      add(:unlisted, :bigint, null: false, default: 0)
      add(:public, :bigint, null: false, default: 0)
    end

    """
    CREATE OR REPLACE FUNCTION #{@function_name}()
    RETURNS TRIGGER AS
    $$
      DECLARE
        hostname character varying(255);
        visibility_new character varying(64);
        visibility_old character varying(64);
        actor character varying(255);
      BEGIN
      IF TG_OP = 'DELETE' THEN
        actor := OLD.actor;
      ELSE
        actor := NEW.actor;
      END IF;
      hostname := split_part(actor, '/', 3);
      IF TG_OP = 'INSERT' THEN
        visibility_new := activity_visibility(NEW.actor, NEW.recipients, NEW.data);
        IF NEW.data->>'type' = 'Create'
            AND visibility_new IN ('public', 'unlisted', 'private', 'direct') THEN
          EXECUTE format('INSERT INTO "counter_cache" ("instance", %1$I) VALUES ($1, 1)
                          ON CONFLICT ("instance") DO
                          UPDATE SET %1$I = "counter_cache".%1$I + 1', visibility_new)
                          USING hostname;
        END IF;
        RETURN NEW;
      ELSIF TG_OP = 'UPDATE' THEN
        visibility_new := activity_visibility(NEW.actor, NEW.recipients, NEW.data);
        visibility_old := activity_visibility(OLD.actor, OLD.recipients, OLD.data);
        IF (NEW.data->>'type' = 'Create')
            AND (OLD.data->>'type' = 'Create')
            AND visibility_new != visibility_old
            AND visibility_new IN ('public', 'unlisted', 'private', 'direct') THEN
          EXECUTE format('UPDATE "counter_cache" SET
                          %1$I = greatest("counter_cache".%1$I - 1, 0),
                          %2$I = "counter_cache".%2$I + 1
                          WHERE "instance" = $1', visibility_old, visibility_new)
                          USING hostname;
        END IF;
        RETURN NEW;
      ELSIF TG_OP = 'DELETE' THEN
        IF OLD.data->>'type' = 'Create' THEN
          visibility_old := activity_visibility(OLD.actor, OLD.recipients, OLD.data);
          EXECUTE format('UPDATE "counter_cache" SET
                          %1$I = greatest("counter_cache".%1$I - 1, 0)
                          WHERE "instance" = $1', visibility_old)
                          USING hostname;
        END IF;
        RETURN OLD;
      END IF;
      END;
    $$
    LANGUAGE 'plpgsql';
    """
    |> execute()

    """
    CREATE TRIGGER #{@trigger_name}
    BEFORE
      INSERT
      OR UPDATE of recipients, data
      OR DELETE
    ON activities
    FOR EACH ROW
      EXECUTE PROCEDURE #{@function_name}();
    """
    |> execute()
  end
end
