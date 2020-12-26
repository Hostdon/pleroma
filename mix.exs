defmodule Pleroma.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pleroma,
      version: version("2.2.1"),
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      elixirc_options: [warnings_as_errors: warnings_as_errors(Mix.env())],
      xref: [exclude: [:eldap]],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls.html": :test],
      # Docs
      name: "Pleroma",
      homepage_url: "https://pleroma.social/",
      source_url: "https://git.pleroma.social/pleroma/pleroma",
      docs: [
        source_url_pattern:
          "https://git.pleroma.social/pleroma/pleroma/blob/develop/%{path}#L%{line}",
        logo: "priv/static/static/logo.png",
        extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/**/*.md"),
        groups_for_extras: [
          "Installation manuals": Path.wildcard("docs/installation/*.md"),
          Configuration: Path.wildcard("docs/config/*.md"),
          Administration: Path.wildcard("docs/admin/*.md"),
          "Pleroma's APIs and Mastodon API extensions": Path.wildcard("docs/api/*.md")
        ],
        main: "readme",
        output: "priv/static/doc"
      ],
      releases: [
        pleroma: [
          include_executables_for: [:unix],
          applications: [ex_syslogger: :load, syslog: :load, eldap: :transient],
          steps: [:assemble, &put_otp_version/1, &copy_files/1, &copy_nginx_config/1],
          config_providers: [{Pleroma.Config.ReleaseRuntimeProvider, nil}]
        ]
      ]
    ]
  end

  def put_otp_version(%{path: target_path} = release) do
    File.write!(
      Path.join([target_path, "OTP_VERSION"]),
      Pleroma.OTPVersion.version()
    )

    release
  end

  def copy_files(%{path: target_path} = release) do
    File.cp_r!("./rel/files", target_path)
    release
  end

  def copy_nginx_config(%{path: target_path} = release) do
    File.cp!(
      "./installation/pleroma.nginx",
      Path.join([target_path, "installation", "pleroma.nginx"])
    )

    release
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Pleroma.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools,
        :comeonin,
        :quack,
        :fast_sanitize,
        :ssl
      ],
      included_applications: [:ex_syslogger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:benchmark), do: ["lib", "benchmarks"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp warnings_as_errors(:prod), do: false
  defp warnings_as_errors(_), do: true

  # Specifies OAuth dependencies.
  defp oauth_deps do
    oauth_strategy_packages =
      System.get_env("OAUTH_CONSUMER_STRATEGIES")
      |> to_string()
      |> String.split()
      |> Enum.map(fn strategy_entry ->
        with [_strategy, dependency] <- String.split(strategy_entry, ":") do
          dependency
        else
          [strategy] -> "ueberauth_#{strategy}"
        end
      end)

    for s <- oauth_strategy_packages, do: {String.to_atom(s), ">= 0.0.0"}
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5.5"},
      {:tzdata, "~> 1.0.3"},
      {:plug_cowboy, "~> 2.3"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.4.4"},
      {:postgrex, ">= 0.15.5"},
      {:oban, "~> 2.1.0"},
      {:gettext, "~> 0.18"},
      {:pbkdf2_elixir, "~> 1.2"},
      {:bcrypt_elixir, "~> 2.2"},
      {:trailing_format_plug, "~> 0.0.7"},
      {:fast_sanitize, "~> 0.2.0"},
      {:html_entities, "~> 0.5", override: true},
      {:phoenix_html, "~> 2.14"},
      {:calendar, "~> 1.0"},
      {:cachex, "~> 3.2"},
      {:poison, "~> 3.0", override: true},
      {:tesla,
       git: "https://github.com/teamon/tesla/",
       ref: "9f7261ca49f9f901ceb73b60219ad6f8a9f6aa30",
       override: true},
      {:castore, "~> 0.1"},
      {:cowlib, "~> 2.9", override: true},
      {:gun,
       github: "ninenines/gun", ref: "921c47146b2d9567eac7e9a4d2ccc60fffd4f327", override: true},
      {:jason, "~> 1.2"},
      {:mogrify, "~> 0.7.4"},
      {:ex_aws, "~> 2.1.6"},
      {:ex_aws_s3, "~> 2.0"},
      {:sweet_xml, "~> 0.6.6"},
      {:earmark, "1.4.3"},
      {:bbcode_pleroma, "~> 0.2.0"},
      {:crypt,
       git: "https://github.com/msantos/crypt.git",
       ref: "f63a705f92c26955977ee62a313012e309a4d77a"},
      {:cors_plug, "~> 2.0"},
      {:web_push_encryption, "~> 0.3"},
      {:swoosh, "~> 1.0"},
      {:phoenix_swoosh, "~> 0.3"},
      {:gen_smtp, "~> 0.13"},
      {:ex_syslogger, "~> 1.4"},
      {:floki, "~> 0.27"},
      {:timex, "~> 3.6"},
      {:ueberauth, "~> 0.4"},
      {:linkify, "~> 0.4.1"},
      {:http_signatures, "~> 0.1.0"},
      {:telemetry, "~> 0.3"},
      {:poolboy, "~> 1.5"},
      {:prometheus, "~> 4.6"},
      {:prometheus_ex,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/prometheus.ex.git",
       ref: "a4e9beb3c1c479d14b352fd9d6dd7b1f6d7deee5",
       override: true},
      {:prometheus_plugs, "~> 1.1"},
      {:prometheus_phoenix, "~> 1.3"},
      # Note: once `prometheus_phx` is integrated into `prometheus_phoenix`, remove the former:
      {:prometheus_phx,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/prometheus-phx.git",
       branch: "no-logging"},
      {:prometheus_ecto, "~> 1.4"},
      {:recon, "~> 2.5"},
      {:quack, "~> 0.1.1"},
      {:joken, "~> 2.0"},
      {:benchee, "~> 1.0"},
      {:pot, "~> 0.11"},
      {:esshd, "~> 0.1.0", runtime: Application.get_env(:esshd, :enabled, false)},
      {:ex_const, "~> 0.2"},
      {:plug_static_index_html, "~> 1.0.0"},
      {:flake_id, "~> 0.1.0"},
      {:concurrent_limiter,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/concurrent_limiter.git",
       ref: "d81be41024569330f296fc472e24198d7499ba78"},
      {:remote_ip,
       git: "https://git.pleroma.social/pleroma/remote_ip.git",
       ref: "b647d0deecaa3acb140854fe4bda5b7e1dc6d1c8"},
      {:captcha,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/elixir-captcha.git",
       ref: "e0f16822d578866e186a0974d65ad58cddc1e2ab"},
      {:restarter, path: "./restarter"},
      {:majic,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/majic", branch: "develop"},
      {:open_api_spex,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/open_api_spex.git",
       ref: "f296ac0924ba3cf79c7a588c4c252889df4c2edd"},

      ## dev & test
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:ex_machina, "~> 2.4", only: :test},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.5", only: :test},
      # temporary downgrade for excoveralls, hackney until hackney max_connections bug will be fixed
      {:excoveralls, "0.12.3", only: :test},
      {:hackney,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/hackney.git",
       ref: "7d7119f0651515d6d7669c78393fd90950a3ec6e",
       override: true},
      {:mox, "~> 0.5", only: :test},
      {:websocket_client, git: "https://github.com/jeremyong/websocket_client.git", only: :test}
    ] ++ oauth_deps()
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.migrate": ["pleroma.ecto.migrate"],
      "ecto.rollback": ["pleroma.ecto.rollback"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      docs: ["pleroma.docs", "docs"],
      analyze: ["credo --strict --only=warnings,todo,fixme,consistency,readability"]
    ]
  end

  # Builds a version string made of:
  # * the application version
  # * a pre-release if ahead of the tag: the describe string (-count-commithash)
  # * branch name
  # * build metadata:
  #   * a build name if `PLEROMA_BUILD_NAME` or `:pleroma, :build_name` is defined
  #   * the mix environment if different than prod
  defp version(version) do
    identifier_filter = ~r/[^0-9a-z\-]+/i

    git_available? = match?({_output, 0}, System.cmd("sh", ["-c", "command -v git"]))

    git_pre_release =
      if git_available? do
        {tag, tag_err} =
          System.cmd("git", ["describe", "--tags", "--abbrev=0"], stderr_to_stdout: true)

        {describe, describe_err} = System.cmd("git", ["describe", "--tags", "--abbrev=8"])
        {commit_hash, commit_hash_err} = System.cmd("git", ["rev-parse", "--short", "HEAD"])

        # Pre-release version, denoted from patch version with a hyphen
        cond do
          tag_err == 0 and describe_err == 0 ->
            describe
            |> String.trim()
            |> String.replace(String.trim(tag), "")
            |> String.trim_leading("-")
            |> String.trim()

          commit_hash_err == 0 ->
            "0-g" <> String.trim(commit_hash)

          true ->
            nil
        end
      end

    # Branch name as pre-release version component, denoted with a dot
    branch_name =
      with true <- git_available?,
           {branch_name, 0} <- System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]),
           branch_name <- String.trim(branch_name),
           branch_name <- System.get_env("PLEROMA_BUILD_BRANCH") || branch_name,
           true <-
             !Enum.any?(["master", "HEAD", "release/", "stable"], fn name ->
               String.starts_with?(name, branch_name)
             end) do
        branch_name =
          branch_name
          |> String.trim()
          |> String.replace(identifier_filter, "-")

        branch_name
      else
        _ -> ""
      end

    build_name =
      cond do
        name = Application.get_env(:pleroma, :build_name) -> name
        name = System.get_env("PLEROMA_BUILD_NAME") -> name
        true -> nil
      end

    env_name = if Mix.env() != :prod, do: to_string(Mix.env())
    env_override = System.get_env("PLEROMA_BUILD_ENV")

    env_name =
      case env_override do
        nil -> env_name
        env_override when env_override in ["", "prod"] -> nil
        env_override -> env_override
      end

    # Pre-release version, denoted by appending a hyphen
    # and a series of dot separated identifiers
    pre_release =
      [git_pre_release, branch_name]
      |> Enum.filter(fn string -> string && string != "" end)
      |> Enum.join(".")
      |> (fn
            "" -> nil
            string -> "-" <> String.replace(string, identifier_filter, "-")
          end).()

    # Build metadata, denoted with a plus sign
    build_metadata =
      [build_name, env_name]
      |> Enum.filter(fn string -> string && string != "" end)
      |> Enum.join(".")
      |> (fn
            "" -> nil
            string -> "+" <> String.replace(string, identifier_filter, "-")
          end).()

    [version, pre_release, build_metadata]
    |> Enum.filter(fn string -> string && string != "" end)
    |> Enum.join()
  end
end
