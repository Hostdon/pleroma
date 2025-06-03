[
  import_deps: [:mneme, :ecto, :ecto_sql, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: [
    "mix.exs",
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "priv/repo/migrations/*.exs",
    "priv/repo/optional_migrations/**/*.exs",
    "priv/scrubbers/*.ex"
  ]
]
