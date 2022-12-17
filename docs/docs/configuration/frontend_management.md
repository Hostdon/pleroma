# Frontend Management

Frontends in Akkoma are swappable, you can pick which you'd like.

For a basic setup, you can set a frontends for the key `primary` and `admin` and the options of `name` and `ref`. This will then make Akkoma serve the frontend from a folder constructed by concatenating the instance static path, `frontends` and the name and ref.

The key `primary` refers to the frontend that will be served by default for general requests. The key `admin` refers to the frontend that will be served at the `/pleroma/admin` path.

If you don't set anything here, you will not have _any_ frontend at all.

Example:

```elixir
config :pleroma, :frontends,
  primary: %{
    "name" => "pleroma-fe",
    "ref" => "stable"
  },
  admin: %{
    "name" => "admin-fe",
    "ref" => "stable"
  },
  mastodon: %{
    "name" => "mastodon-fe",
    "ref" => "akkoma"
  }
```

This would serve the frontend from the the folder at `$instance_static/frontends/pleroma/stable`. You have to copy the frontend into this folder yourself. You can choose the name and ref any way you like, but they will be used by mix tasks to automate installation in the future, the name referring to the project and the ref referring to a commit.

Refer to [the frontend CLI task](../../administration/CLI_tasks/frontend) for how to install the frontend's files

If you choose not to install a frontend for whatever reason, it is recommended that you enable [`:static_fe`](#static_fe) to allow remote users to click "view remote source". Don't bother with this if you've got no unauthenticated access though.

You can also replace the default "no frontend" page by placing an `index.html` file under your `instance/static/` directory.

## Mastodon-FE

Akkoma supports both [glitchsoc](https://github.com/glitch-soc/mastodon)'s more "vanilla" mastodon frontend,
as well as [fedibird](https://github.com/fedibird/mastodon)'s extended frontend which has near-feature-parity with akkoma (with quoting and reactions).

To enable either one, you must run the `frontend.install` task for either `mastodon-fe` or `fedibird-fe` (both `--ref akkoma`), then make sure
`:pleroma, :frontends, :mastodon` references the one you want.

## Swagger (openAPI) documentation viewer

If you're a developer and you'd like a human-readable rendering of the
API documentation, you can enable [Swagger UI](https://github.com/swagger-api/swagger-ui).

In your config:

```elixir
config :pleroma, :frontends,
  swagger: %{
    "name" => "swagger-ui",
    "ref" => "stable",
    "enabled" => true
  }
```

Then run the [pleroma.frontend cli task](../../administration/CLI_tasks/frontend) with the name of `swagger-ui` to install the distribution files.

You will now be able to view documentation at `/akkoma/swaggerui`
