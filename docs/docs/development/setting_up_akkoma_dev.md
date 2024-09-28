# Setting up a Akkoma development environment

Akkoma requires some adjustments from the defaults for running the instance locally. The following should help you to get started.

## Installing

1. Install Akkoma as explained in [the docs](../installation/debian_based_en.md), with some exceptions:
    * No need to create a dedicated akkoma user, it's easier to just use your own user
    * You can use your own fork of the repository and add akkoma as a remote `git remote add akkoma 'https://akkoma.dev/AkkomaGang/akkoma.git'`
    * For domain you can use `localhost`
    * For the DB you can still choose a dedicated user. The mix tasks sets it up, so it's no extra work for you
    * instead of creating a `prod.secret.exs`, create `dev.secret.exs`
    * No need to prefix with `MIX_ENV=prod`. We're using dev and that's the default MIX_ENV
    * You can skip nginx and systemd
    * For front-end, you'll probably want to install and use the develop branch instead of the stable branch. There's no guarantee that the stable branch of the FE will always work on the develop branch of the BE.
2. Change the dev.secret.exs
    * Change the FE settings to use the installed branch (see also [Frontend Management](/configuration/frontend_management/))
    * Change the scheme in `config :pleroma, Pleroma.Web.Endpoint` to http (see examples below)
    * If you want to change other settings, you can do that too
3. You can now start the server with `mix phx.server`. Once it's build and started, you can access the instance on `http://<host>:<port>` (e.g.http://localhost:4000 ) and should be able to do everything locally you normally can.

Example on how to install pleroma-fe and admin-fe using it's develop branch
```sh
mix pleroma.frontend install pleroma-fe --ref develop
mix pleroma.frontend install admin-fe --ref develop
```

Example config to use the pleroma-fe and admin-fe installed from the develop branch
```elixir
config :pleroma, :frontends,
  primary: %{"name" => "pleroma-fe", "ref" => "develop"},
  admin: %{"name" => "admin-fe", "ref" => "develop"}
```

Example config to change the scheme to http. Change the port if you want to run on another port.
```elixir
config :pleroma, Pleroma.Web.Endpoint,
  url: [host: "localhost", scheme: "http", port: 4000],
```

Example config to disable captcha. This makes it a bit easier to create test-users.
```elixir
config :pleroma, Pleroma.Captcha,
  enabled: false
```

Example config to change the log level to info
```elixir
config :logger, :console,
  # :debug :info :warning :error
  level: :info
```

## Testing with HTTPS

If you end up developing alongside other software like misskey,
you will not be able to federate without an SSL certificate. You should
be able to use the snakeoil certificate that comes standard with most
distributions or generate one from scratch, then force elixir to accept it.

HTTP clients are none too keen to accept self-signed certs, but we can do
this:

```elixir
config :pleroma, :http,
  adapter: [
    pools: %{
      default: [
        conn_opts: [
          transport_opts: [
            verify: :verify_none
          ]
        ]
      ]
    }
  ]
```

Now your SSL requests will work. Hooray.

## Testing

1. Create a `test.secret.exs` file with the content as shown below
2. Create the database user and test database.
    1. You can use the `config/setup_db.psql` as a template. Copy the file if you want and change the database name, user and password to the values for the test-database (e.g. 'akkoma_local_test' for database and user). Then run this file like you did during installation.
    2. The tests will try to create the Database, so we'll have to allow our test-database user to create databases, `sudo -Hu postgres psql -c "ALTER USER akkoma_local_test WITH CREATEDB;"`
3. Run the tests with `mix test`. The tests should succeed.

Example content for the `test.secret.exs` file. Feel free to use another user, database name or password, just make sure the database is dedicated for the testing environment.
```elixir
# Akkoma test configuration

# NOTE: This file should not be committed to a repo or otherwise made public
# without removing sensitive information.

import Config

config :pleroma, Pleroma.Repo,
  username: "akkoma_local_test",
  password: "mysuperduperpassword",
  database: "akkoma_local_test",
  hostname: "localhost"

```

## Updating

Update Akkoma as explained in [the docs](../administration/updating.md). Just make sure you pull from upstream and not from your own fork.

## Working on multiple branches

If you develop on a separate branch, it's possible you did migrations that aren't merged into another branch you're working on. In that case, it's probably best to set up multiple Akkoma instances each with their own database. If you finished with a branch and want to switch back to develop to start a new branch from there, you can drop the database and recreate the database (e.g. by using `config/setup_db.psql`). The commands to drop and recreate the database can be found in [the docs](../administration/backup.md).
