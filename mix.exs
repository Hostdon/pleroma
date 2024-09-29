defmodule Pleroma.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pleroma,
      version: version("3.13.2"),
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      elixirc_options: [warnings_as_errors: warnings_as_errors()],
      xref: [exclude: [:eldap]],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls.html": :test],
      # Docs
      name: "Akkoma",
      homepage_url: "https://akkoma.dev/",
      source_url: "https://akkoma.dev/AkkomaGang/akkoma",
      docs: [
        source_url_pattern: "https://akkoma.dev/AkkomaGang/akkoma/blob/develop/%{path}#L%{line}",
        logo: "priv/static/logo-512.png",
        extras: ["README.md", "CHANGELOG.md"] ++ Path.wildcard("docs/docs/**/*.md"),
        groups_for_extras: [
          "Installation manuals": Path.wildcard("docs/docs/installation/*.md"),
          Configuration: Path.wildcard("docs/docs/config/*.md"),
          Administration: Path.wildcard("docs/docs/admin/*.md"),
          "Pleroma's APIs and Mastodon API extensions": Path.wildcard("docs/docs/api/*.md")
        ],
        main: "readme",
        output: "priv/static/doc"
      ],
      releases: [
        pleroma: [
          include_executables_for: [:unix],
          applications: [ex_syslogger: :load, syslog: :load, eldap: :transient],
          steps: [:assemble, &put_otp_version/1, &copy_files/1, &copy_nginx_config/1],
          config_providers: [{Pleroma.Config.ReleaseRuntimeProvider, []}]
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
      "./installation/nginx/akkoma.nginx",
      Path.join([target_path, "installation", "akkoma.nginx"])
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
        :fast_sanitize,
        :os_mon,
        :ssl
      ],
      included_applications: [:ex_syslogger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:benchmark), do: ["lib", "benchmarks", "priv/scrubbers"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp warnings_as_errors, do: System.get_env("CI") == "true"

  # Specifies OAuth dependencies.
  defp oauth_deps do
    oauth_strategy_packages =
      "OAUTH_CONSUMER_STRATEGIES"
      |> System.get_env()
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
      {:phoenix, "~> 1.7.0"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:tzdata, "~> 1.1.1"},
      {:plug_cowboy, "~> 2.6"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.4"},
      {:inet_cidr, "~> 1.0.0"},
      {:ecto_enum, "~> 1.4"},
      {:ecto_sql, "~> 3.10.0"},
      {:postgrex, "~> 0.17.2"},
      {:oban, "~> 2.17.8"},
      {:gettext, "~> 0.22.3"},
      {:bcrypt_elixir, "~> 3.0.1"},
      {:fast_sanitize, "~> 0.2.3"},
      {:html_entities, "~> 0.5"},
      {:phoenix_html, "~> 3.3"},
      {:calendar, "~> 1.0"},
      {:cachex, "~> 3.6"},
      {:tesla, "~> 1.7"},
      {:castore, "~> 1.0"},
      {:cowlib, "~> 2.12"},
      {:finch, "~> 0.16.0"},
      {:jason, "~> 1.4"},
      {:trailing_format_plug, "~> 0.0.7"},
      {:mogrify, "~> 0.9"},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_s3, "~> 2.4"},
      {:sweet_xml, "~> 0.7"},
      {:earmark, "~> 1.4"},
      {:bbcode_pleroma, "~> 0.2.0"},
      {:argon2_elixir, "~> 3.1"},
      {:cors_plug, "~> 3.0"},
      {:web_push_encryption, "~> 0.3.1"},
      {:swoosh, "~> 1.14.2"},
      # for gmail adapter in swoosh
      {:mail, ">= 0.0.0"},
      {:phoenix_swoosh, "~> 1.2"},
      {:gen_smtp, "~> 1.2"},
      {:ex_syslogger, "~> 2.0.0"},
      {:floki, "~> 0.34"},
      {:timex, "~> 3.7"},
      {:ueberauth, "== 0.10.5"},
      {:linkify, git: "https://akkoma.dev/AkkomaGang/linkify.git"},
      {:http_signatures,
       git: "https://akkoma.dev/AkkomaGang/http_signatures.git",
       ref: "6640ce7d24c783ac2ef56e27d00d12e8dc85f396"},
      {:telemetry, "~> 1.2"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_prometheus_core, "~> 1.1.0"},
      {:poolboy, "~> 1.5"},
      {:recon, "~> 2.5"},
      {:joken, "~> 2.6"},
      {:benchee, "~> 1.1"},
      {:pot, "~> 1.0"},
      {:ex_const, "~> 0.2"},
      {:plug_static_index_html, "~> 1.0.0"},
      {:flake_id, "~> 0.1.0"},
      {:concurrent_limiter,
       git: "https://akkoma.dev/AkkomaGang/concurrent-limiter.git",
       ref: "a9e0b3d64574bdba761f429bb4fba0cf687b3338"},
      {:remote_ip, "~> 1.1.0"},
      {:captcha,
       git: "https://git.pleroma.social/pleroma/elixir-libraries/elixir-captcha.git",
       ref: "90f6ce7672f70f56708792a98d98bd05176c9176"},
      {:restarter, path: "./restarter"},
      {:majic,
       git: "https://akkoma.dev/AkkomaGang/majic.git",
       ref: "80540b36939ec83f48e76c61e5000e0fd67706f0"},
      {:eblurhash, "~> 1.2.2"},
      {:open_api_spex, "~> 3.17"},
      {:search_parser,
       git: "https://github.com/FloatingGhost/pleroma-contrib-search-parser.git",
       ref: "08971a81e68686f9ac465cfb6661d51c5e4e1e7f"},
      {:nimble_parsec, "~> 1.3", override: true},
      {:ecto_psql_extras, "~> 0.7"},
      {:elasticsearch,
       git: "https://akkoma.dev/AkkomaGang/elasticsearch-elixir.git", ref: "main"},
      {:mfm_parser,
       git: "https://akkoma.dev/AkkomaGang/mfm-parser.git",
       ref: "b21ab7754024af096f2d14247574f55f0063295b"},

      ## dev & test
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3.8", only: :test},
      {:excoveralls, "0.16.1", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:websockex, "~> 0.4.3", only: :test},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:elixir_xml_to_map, "~> 3.0", only: :test},
      {:mint, "~> 1.5.1", override: true},
      {:nimble_pool, "~> 1.0", override: true}
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
      analyze: ["credo --strict --only=warnings,todo,fixme,consistency,readability"],
      copyright: &add_copyright/1,
      "copyright.bump": &bump_copyright/1
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
    dotgit_present? = File.exists?(".git")

    git_pre_release =
      if git_available? and dotgit_present? do
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
           true <- dotgit_present?,
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

  defp add_copyright(_) do
    year = NaiveDateTime.utc_now().year
    template = ~s[\
# Pleroma: A lightweight social networking server
# Copyright © 2017-#{year} Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
# Akkoma: Magically expressive social media
# Copyright © 2022-#{year} Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

] |> String.replace("\n", "\\n")

    find = "find lib test priv -type f \\( -name '*.ex' -or -name '*.exs' \\) -exec "
    grep = "grep -L '# Copyright © [0-9\-]* Pleroma' {} \\;"
    xargs = "xargs -n1 sed -i'' '1s;^;#{template};'"

    :os.cmd(String.to_charlist("#{find}#{grep} | #{xargs}"))
  end

  defp bump_copyright(_) do
    year = NaiveDateTime.utc_now().year
    find = "find lib test priv -type f \\( -name '*.ex' -or -name '*.exs' \\)"

    xargs =
      "xargs sed -i'' 's;# Copyright © [0-9\-]* Pleroma.*$;# Copyright © 2017-#{year} Pleroma Authors <https://pleroma.social/>;'"

    :os.cmd(String.to_charlist("#{find} | #{xargs}"))
  end
end
