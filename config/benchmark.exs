import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pleroma, Pleroma.Web.Endpoint,
  http: [port: 4001],
  url: [port: 4001]

# Disable captha for tests
config :pleroma, Pleroma.Captcha,
  # It should not be enabled for automatic tests
  enabled: false,
  # A fake captcha service for tests
  method: Pleroma.Captcha.Mock

# Print only warnings and errors during test
config :logger, level: :warn

config :pleroma, :auth, oauth_consumer_strategies: []

config :pleroma, Pleroma.Upload, filters: [], link_name: false

config :pleroma, Pleroma.Uploaders.Local, uploads: "test/uploads"

config :pleroma, Pleroma.Emails.Mailer, adapter: Swoosh.Adapters.Test, enabled: true

config :pleroma, :instance,
  email: "admin@example.com",
  notify_email: "noreply@example.com",
  skip_thread_containment: false,
  federating: false,
  external_user_synchronization: false

config :pleroma, :activitypub, sign_object_fetches: false

# Configure your database
config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "pleroma_benchmark",
  hostname: System.get_env("DB_HOST") || "localhost",
  pool_size: 10

# Reduce hash rounds for testing
config :pleroma, :password, iterations: 1

config :tesla, adapter: Tesla.Mock

config :pleroma, :rich_media,
  enabled: false,
  ignore_hosts: [],
  ignore_tld: ["local", "localdomain", "lan"]

config :web_push_encryption, :vapid_details,
  subject: "mailto:administrator@example.com",
  public_key:
    "BLH1qVhJItRGCfxgTtONfsOKDc9VRAraXw-3NsmjMngWSh7NxOizN6bkuRA7iLTMPS82PjwJAr3UoK9EC1IFrz4",
  private_key: "_-XZ0iebPrRfZ_o0-IatTdszYa8VCH1yLN-JauK7HHA"

config :pleroma, Pleroma.ScheduledActivity,
  daily_user_limit: 2,
  total_user_limit: 3,
  enabled: false

config :pleroma, :rate_limit,
  search: [{1000, 30}, {1000, 30}],
  app_account_creation: {10_000, 5},
  password_reset: {1000, 30}

config :pleroma, :http_security, report_uri: "https://endpoint.com"

rum_enabled = System.get_env("RUM_ENABLED") == "true"
config :pleroma, :database, rum_enabled: rum_enabled
IO.puts("RUM enabled: #{rum_enabled}")

config :pleroma, Pleroma.ReverseProxy.Client, Pleroma.ReverseProxy.ClientMock

if File.exists?("./config/benchmark.secret.exs") do
  import_config "benchmark.secret.exs"
else
  IO.puts(
    "You may want to create benchmark.secret.exs to declare custom database connection parameters."
  )
end
