# Managing uploads

{! administration/CLI_tasks/general_cli_task_info.include !}

## Migrate uploads from local to remote storage
=== "OTP"

    ```sh
     ./bin/pleroma_ctl uploads migrate_local <target_uploader> [option ...]
    ```

=== "From Source"

    ```sh
    mix pleroma.uploads migrate_local <target_uploader> [option ...]
    ```

### Options
- `--delete` - delete local uploads after migrating them to the target uploader

A list of available uploaders can be seen in [Configuration Cheat Sheet](../../configuration/cheatsheet.md#pleromaupload)

## Rewriting old media URLs

After a migration has taken place, old URLs in your database will not have been changed. You
will want to run this task to update these URLs.

Use the full URL here. So if you moved from `media.example.com/media` to `media.another.com/data`, you'd run with arguments
`old_url = https://media.example.com/media` and `new_url = https://media.another.com/data`.

=== "OTP"

    ```sh
     ./bin/pleroma_ctl uploads rewrite_media_domain <old_url> <new_url>
    ```

=== "From Source"

    ```sh
    mix pleroma.uploads rewrite_media_domain <old_url> <new_url>
    ```

### Options
- `--dry-run` - Do not action any update and simply print what _would_ happen
