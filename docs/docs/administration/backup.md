# Backup/Restore/Move/Remove your instance

## Backup

1. Stop the Akkoma service.
2. Go to the working directory of Akkoma (default is `/opt/akkoma`)
3. Run[¹] `sudo -Hu postgres pg_dump -d akkoma --format=custom -f </path/to/backup_location/akkoma.pgdump>` (make sure the postgres user has write access to the destination file)
4. Copy `akkoma.pgdump`, `config/prod.secret.exs`[²], `config/setup_db.psql` (if still available) and the `uploads` folder to your backup destination. If you have other modifications, copy those changes too.
5. Restart the Akkoma service.

[¹]: We assume the database name is "akkoma". If not, you can find the correct name in your config files.  
[²]: If you've installed using OTP, you need `config/config.exs` instead of `config/prod.secret.exs`.  

## Restore/Move

1. Optionally reinstall Akkoma (either on the same server or on another server if you want to move servers).
2. Stop the Akkoma service.
3. Go to the working directory of Akkoma (default is `/opt/akkoma`)
4. Copy the above mentioned files back to their original position.
5. Drop the existing database and user if restoring in-place[¹]. `sudo -Hu postgres psql -c 'DROP DATABASE akkoma;';` `sudo -Hu postgres psql -c 'DROP USER akkoma;'`
6. Restore the database schema and akkoma role using either of the following options
    * You can use the original `setup_db.psql` if you have it[²]: `sudo -Hu postgres psql -f config/setup_db.psql`.
    * Or recreate the database and user yourself (replace the password with the one you find in the config file) `sudo -Hu postgres psql -c "CREATE USER akkoma WITH ENCRYPTED PASSWORD '<database-password-wich-you-can-find-in-your-config-file>'; CREATE DATABASE akkoma OWNER akkoma;"`.
7. Now restore the Akkoma instance's data into the empty database schema[¹][³]: `sudo -Hu postgres pg_restore -d akkoma -v -1 </path/to/backup_location/akkoma.pgdump>`
8. If you installed a newer Akkoma version, you should run `MIX_ENV=prod mix ecto.migrate`[⁴]. This task performs database migrations, if there were any.
9. Restart the Akkoma service.
10. Run `sudo -Hu postgres vacuumdb --all --analyze-in-stages`. This will quickly generate the statistics so that postgres can properly plan queries.
11. If setting up on a new server configure Nginx by using the `installation/akkoma.nginx` config sample or reference the Akkoma installation guide for your OS which contains the Nginx configuration instructions.

[¹]: We assume the database name and user are both "akkoma". If not, you can find the correct name in your config files.  
[²]: You can recreate the `config/setup_db.psql` by running the `mix pleroma.instance gen` task again. You can ignore most of the questions, but make the database user, name, and password the same as found in your backed up config file. This will also create a new `config/generated_config.exs` file which you may delete as it is not needed.  
[³]: `pg_restore` will add data before adding indexes. The indexes are added in alphabetical order. There's one index, `activities_visibility_index` which may take a long time because it can't make use of an index that's only added later. You can significantly speed up restoration by skipping this index and add it afterwards. For that, you can do the following (we assume the akkoma.pgdump is in the directory you're running the commands):  

```sh
pg_restore -l akkoma.pgdump > db.list

# Comment out the step for creating activities_visibility_index by adding a semi colon at the start of the line
sed -i -E 's/(.*activities_visibility_index.*)/;\1/' db.list

# We restore the database using the db.list list-file
sudo -Hu postgres pg_restore -L db.list -d akkoma -v -1 akkoma.pgdump

# You can see the sql statement with which to create the index using
grep -Eao 'CREATE INDEX activities_visibility_index.*' akkoma.pgdump

# Then create the index manually
# Make sure that the command to create is correct! You never know it has changed since writing this guide
sudo -Hu postgres psql -d pleroma_ynh -c "CREATE INDEX activities_visibility_index ON public.activities USING btree (public.activity_visibility(actor, recipients, data), id DESC NULLS LAST) WHERE ((data ->> 'type'::text) = 'Create'::text);"
```
[⁴]: Prefix with `MIX_ENV=prod` to run it using the production config file.  

## Remove

1. Optionally you can remove the users of your instance. This will trigger delete requests for their accounts and posts. Note that this is 'best effort' and doesn't mean that all traces of your instance will be gone from the fediverse.
    * You can do this from the admin-FE where you can select all local users and delete the accounts using the *Moderate multiple users* dropdown.
    * You can also list local users and delete them individually using the CLI tasks for [Managing users](./CLI_tasks/user.md).
2. Stop the Akkoma service `systemctl stop akkoma`
3. Disable Akkoma from systemd `systemctl disable akkoma`
4. Remove the files and folders you created during installation (see installation guide). This includes the akkoma, nginx and systemd files and folders.
5. Reload nginx now that the configuration is removed `systemctl reload nginx`
6. Remove the database and database user[¹] `sudo -Hu postgres psql -c 'DROP DATABASE akkoma;';` `sudo -Hu postgres psql -c 'DROP USER akkoma;'`
7. Remove the system user `userdel akkoma`
8. Remove the dependencies that you don't need anymore (see installation guide). Make sure you don't remove packages that are still needed for other software that you have running!

[¹]: We assume the database name and user are both "akkoma". If not, you can find the correct name in your config files.  
