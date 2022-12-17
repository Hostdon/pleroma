# Migrating to Akkoma

## Why should you migrate?

aside from actually responsive maintainer(s)? let's lookie here, we've got:

- custom emoji reactions
- misskey markdown (MFM) rendering and posting support
- elasticsearch support (because pleroma search is GARBAGE)
- latest develop pleroma-fe additions
- local-only posting
- automatic post translation
- the mastodon frontend back in all its glory
- probably more, this is like 3.5 years of IHBA additions finally compiled

## Actually migrating

Let's say you're very cool and have decided to move to the cooler
fork of Akkoma - luckily this isn't very hard.

You'll need to update the backend, then possibly the frontend, depending
on your setup.

## From Source

If you're running the source Akkoma install, you'll need to set the
upstream git URL then just rebuild - that'll be:

```bash
git remote set-url origin https://akkoma.dev/AkkomaGang/akkoma.git/
git fetch origin
git pull -r
# or, if you're on an instance-specific branch, you may want
# to run "git merge stable" instead (or develop if you want)
```

### WARNING - Migrating from Pleroma Develop
If you are on pleroma develop, and have updated since 2022-08, you may have issues with database migrations.

Please roll back the given migrations:

```bash
MIX_ENV=prod mix ecto.rollback --migrations-path priv/repo/optional_migrations/pleroma_develop_rollbacks -n3
```

Then compile, migrate and restart as usual.

## From OTP

This will just be setting the update URL - find your flavour from the [mapping on the install guide](../otp_en/#detecting-flavour) first.

```bash
export FLAVOUR=[the flavour you found above]

./bin/pleroma_ctl update --zip-url https://akkoma-updates.s3-website.fr-par.scw.cloud/stable/akkoma-$FLAVOUR.zip
./bin/pleroma_ctl migrate
```

Then restart. When updating in the future, you canjust use

```bash
./bin/pleroma_ctl update --branch stable
```

## Frontend changes

Akkoma comes with a few frontend changes as well as backend ones,
your upgrade path here depends on your setup

### I just run with the built-in frontend

You'll need to run a couple of commands,

=== "OTP"
    ```sh
    ./bin/pleroma_ctl frontend install pleroma-fe --ref stable
    # and also, if desired
    ./bin/pleroma_ctl frontend install admin-fe --ref stable
    ```

=== "From Source"
    ```sh
    mix pleroma.frontend install pleroma-fe --ref stable
    mix pleroma.frontend install admin-fe --ref stable
    ```

### I've run the mix task to install a frontend

Hooray, just run it again to update the frontend to the latest build.
See above for that command.

### I compile the JS from source

Your situation will likely be unique - you'll need the changes in the
[forked pleroma-fe repository](https://akkoma.dev/AkkomaGang/pleroma-fe),
and either merge or cherry-pick from there depending on how you've got
things.

## Common issues

### The frontend doesn't show after installing it

This may occur if you are using database configuration.

Sometimes the config in your database will cause akkoma to still report
that there's no frontend, even when you've run the install.

To fix this, run:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl config delete pleroma frontends
    ```

=== "From Source"
    ```sh
    mix pleroma.config delete pleroma frontends
    ```

which will remove the config from the database. Things should work now.