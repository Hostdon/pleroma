use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pleroma, Pleroma.Web.Endpoint,
  http: [port: 4001],
  url: [port: 4001],
  server: true

# Disable captha for tests
config :pleroma, Pleroma.Captcha,
  # It should not be enabled for automatic tests
  enabled: false,
  # A fake captcha service for tests
  method: Pleroma.Captcha.Mock

# Print only warnings and errors during test
config :logger, :console,
  level: :warn,
  format: "\n[$level] $message\n"

config :pleroma, :fed_sockets,
  enabled: false,
  connection_duration: 5,
  rejection_duration: 5

config :pleroma, :auth, oauth_consumer_strategies: []

config :pleroma, Pleroma.Upload,
  filters: [],
  link_name: false,
  default_description: :filename

config :pleroma, Pleroma.Uploaders.Local, uploads: "test/uploads"

config :pleroma, Pleroma.Emails.Mailer, adapter: Swoosh.Adapters.Test, enabled: true

config :pleroma, :instance,
  email: "admin@example.com",
  notify_email: "noreply@example.com",
  skip_thread_containment: false,
  federating: false,
  external_user_synchronization: false,
  static_dir: "test/instance_static/"

config :pleroma, :activitypub, sign_object_fetches: false

# Configure your database
config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "pleroma_test",
  hostname: System.get_env("DB_HOST") || "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# Reduce hash rounds for testing
config :pbkdf2_elixir, rounds: 1

config :tesla, adapter: Tesla.Mock

config :pleroma, :rich_media,
  enabled: false,
  ignore_hosts: [],
  ignore_tld: ["local", "localdomain", "lan"]

config :pleroma, :instance,
  multi_factor_authentication: [
    totp: [
      # digits 6 or 8
      digits: 6,
      period: 30
    ],
    backup_codes: [
      number: 2,
      length: 6
    ]
  ]

config :web_push_encryption, :vapid_details,
  subject: "mailto:administrator@example.com",
  public_key:
    "BLH1qVhJItRGCfxgTtONfsOKDc9VRAraXw-3NsmjMngWSh7NxOizN6bkuRA7iLTMPS82PjwJAr3UoK9EC1IFrz4",
  private_key: "_-XZ0iebPrRfZ_o0-IatTdszYa8VCH1yLN-JauK7HHA"

config :pleroma, Oban,
  queues: false,
  crontab: false,
  plugins: false

config :pleroma, Pleroma.ScheduledActivity,
  daily_user_limit: 2,
  total_user_limit: 3,
  enabled: false

config :pleroma, :rate_limit, %{}

config :pleroma, :http_security, report_uri: "https://endpoint.com"

config :pleroma, :http, send_user_agent: false

rum_enabled = System.get_env("RUM_ENABLED") == "true"
config :pleroma, :database, rum_enabled: rum_enabled
IO.puts("RUM enabled: #{rum_enabled}")

config :joken, default_signer: "yU8uHKq+yyAkZ11Hx//jcdacWc8yQ1bxAAGrplzB0Zwwjkp35v0RK9SO8WTPr6QZ"

config :pleroma, Pleroma.ReverseProxy.Client, Pleroma.ReverseProxy.ClientMock

config :pleroma, :modules, runtime_dir: "test/fixtures/modules"

config :pleroma, Pleroma.Gun, Pleroma.GunMock

config :pleroma, Pleroma.Emails.NewUsersDigestEmail, enabled: true

config :pleroma, Pleroma.Web.Plugs.RemoteIp, enabled: false

config :pleroma, Pleroma.Web.ApiSpec.CastAndValidate, strict: true

config :pleroma, Pleroma.Uploaders.S3,
  bucket: nil,
  streaming_enabled: true,
  public_endpoint: nil

config :tzdata, :autoupdate, :disabled

config :pleroma, :mrf, policies: []

if File.exists?("./config/test.secret.exs") do
  import_config "test.secret.exs"
else
  IO.puts(
    "You may want to create test.secret.exs to declare custom database connection parameters."
  )
end
