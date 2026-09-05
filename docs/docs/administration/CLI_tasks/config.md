# Transferring the config to/from the database

{! administration/CLI_tasks/general_cli_task_info.include !}

## Transfer config from file to DB.

!!! note
    You need to add the following to your config before executing this command:

    ```elixir
    config :pleroma, configurable_from_database: true
    ```

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config migrate_to_db
    ```

=== "From Source"

    ```sh
    mix pleroma.config migrate_to_db
    ```

## Transfer config from DB to `config/env.exported_from_db.secret.exs`

!!! note
    In-Database configuration will still be applied after executing this command unless you set the following in your config:

    ```elixir
    config :pleroma, configurable_from_database: false
    ```

Options:

- `<path>` - where to save migrated config. E.g. `--path=/tmp`. If the file was saved into a non-standard directory, you must manually copy it into a location where Pleroma can read it. For OTP the install path will be `PLEROMA_CONFIG_PATH` or `/etc/akkoma`. For installation from source it’s the `config` directory in the akkoma folder.
- `<env>` - environment, for which is migrated config. By default, it’s `prod`.
- To delete transferred settings from database the optional flag `-d` can be used

=== "OTP"
    ```sh
     ./bin/pleroma_ctl config migrate_from_db [--env=<env>] [-d] [--path=<path>]
    ```

=== "From Source"
    ```sh
    mix pleroma.config migrate_from_db [--env=<env>] [-d] [--path=<path>]
    ```

## Dump all config settings defined in the database

=== "OTP"

    ```sh
     ./bin/pleroma_ctl config dump
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump
    ```

## List individual configuration groups in the database

=== "OTP"

    ```sh
     ./bin/pleroma_ctl config groups
    ```

=== "From Source"

    ```sh
    mix pleroma.config groups
    ```

## Dump the saved configuration values for a specific group or key

e.g., this shows all the settings under `config :pleroma`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config dump pleroma
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump pleroma
    ```

To get values under a specific key:

e.g., this shows all the settings under `config :pleroma, :instance`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config dump pleroma instance
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump pleroma instance
    ```

## Delete the saved configuration values for a specific group or key

e.g., this deletes all the settings under `config :tesla`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config delete [--force] tesla
    ```

=== "From Source"

    ```sh
    mix pleroma.config delete [--force] tesla
    ```

To delete values under a specific key:

e.g., this deletes all the settings under `config :phoenix, :stacktrace_depth`

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config delete [--force] phoenix stacktrace_depth
    ```

=== "From Source"

    ```sh
    mix pleroma.config delete [--force] phoenix stacktrace_depth
    ```

## Remove all settings from the database

This forcibly removes all saved values in the database.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config [--force] reset
    ```

=== "From Source"

    ```sh
    mix pleroma.config [--force] reset
    ```

## Dumping specific configuration values to JSON

If you want to bulk-modify configuration values (for example, for MRF modifications),
it may be easier to dump the values to JSON and then modify them in a text editor.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config dump_to_file group key path
    # For example, to dump the MRF simple configuration:
    ./bin/pleroma_ctl config dump_to_file pleroma mrf_simple /tmp/mrf_simple.json
    ```

=== "From Source"

    ```sh
    mix pleroma.config dump_to_file group key path
    # For example, to dump the MRF simple configuration:
    mix pleroma.config dump_to_file pleroma mrf_simple /tmp/mrf_simple.json
    ```

## Loading specific configuration values from JSON

!!!note
    This will overwrite any existing value in the database, and can
    cause crashes if you do not have exactly the correct formatting.

Once you have modified the JSON file, you can load it back into the database.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl config load_from_file path
    # For example, to load the MRF simple configuration:
    ./bin/pleroma_ctl config load_from_file /tmp/mrf_simple.json
    ```

=== "From Source"

    ```sh
    mix pleroma.config load_from_file path
    # For example, to load the MRF simple configuration:
    mix pleroma.config load_from_file /tmp/mrf_simple.json
    ```

!!! note
    An instance reboot is needed for many changes to take effect,
    you may want to visit `/api/v1/pleroma/admin/restart` on your instance
    to soft-restart the instance.

## Remove non-whitelisted configs from the database

This removes any configuration value that is not explicitly whitelisted by `:pleroma, :database_config_whitelist`. Might be useful after updating the whitelist.

=== "OTP"
    ```sh
    ./bin/pleroma_ctl config filter_whitelisted
    ```

=== "From Source"
    ```sh
    mix pleroma.config filter_whitelisted
    ```
