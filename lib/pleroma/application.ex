# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Application do
  use Application

  import Cachex.Spec

  alias Pleroma.Config

  require Logger

  @name Mix.Project.config()[:name]
  @version Mix.Project.config()[:version]
  @repository Mix.Project.config()[:source_url]
  @mix_env Mix.env()

  def name, do: @name
  def version, do: @version
  def named_version, do: @name <> " " <> @version
  def repository, do: @repository

  def user_agent do
    if Process.whereis(Pleroma.Web.Endpoint) do
      case Config.get([:http, :user_agent], :default) do
        :default ->
          info = "#{Pleroma.Web.Endpoint.url()} <#{Config.get([:instance, :email], "")}>"
          named_version() <> "; " <> info

        custom ->
          custom
      end
    else
      # fallback, if endpoint is not started yet
      "Pleroma Data Loader"
    end
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Scrubbers are compiled at runtime and therefore will cause a conflict
    # every time the application is restarted, so we disable module
    # conflicts at runtime
    Code.compiler_options(ignore_module_conflict: true)
    Config.Holder.save_default()
    Pleroma.HTML.compile_scrubbers()
    Pleroma.Config.Oban.warn()
    Config.DeprecationWarnings.warn()
    Pleroma.Web.Plugs.HTTPSecurityPlug.warn_if_disabled()
    Pleroma.ApplicationRequirements.verify!()
    load_all_pleroma_modules()
    load_custom_modules()
    Pleroma.Docs.JSON.compile()
    limiters_setup()

    # Define workers and child supervisors to be supervised
    children =
      [
        Pleroma.Repo,
        Config.TransferTask,
        Pleroma.Emoji,
        Pleroma.Web.Plugs.RateLimiter.Supervisor,
        {Task.Supervisor, name: Pleroma.TaskSupervisor}
      ] ++
        cachex_children() ++
        http_children() ++
        [
          Pleroma.Stats,
          {Majic.Pool, [name: Pleroma.MajicPool, pool_size: Config.get([:majic_pool, :size], 2)]},
          {Oban, Config.get(Oban)},
          Pleroma.Web.Endpoint,
          Pleroma.Web.Telemetry
        ] ++
        elasticsearch_children() ++
        task_children() ++
        dont_run_in_test(@mix_env)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    # If we have a lot of caches, default max_restarts can cause test
    # resets to fail.
    # Go for the default 3 unless we're in test
    max_restarts =
      if @mix_env == :test do
        1000
      else
        3
      end

    opts = [strategy: :one_for_one, name: Pleroma.Supervisor, max_restarts: max_restarts]

    case Supervisor.start_link(children, opts) do
      {:ok, data} ->
        {:ok, data}

      e ->
        Logger.critical("Failed to start!")
        Logger.critical("#{inspect(e)}")
        e
    end
  end

  def load_custom_modules do
    dir = Config.get([:modules, :runtime_dir])

    if dir && File.exists?(dir) do
      dir
      |> Pleroma.Utils.compile_dir()
      |> case do
        {:error, _errors, _warnings} ->
          raise "Invalid custom modules"

        {:ok, modules, _warnings} ->
          if @mix_env != :test do
            Enum.each(modules, fn mod ->
              Logger.info("Custom module loaded: #{inspect(mod)}")
            end)
          end

          :ok
      end
    end
  end

  def load_all_pleroma_modules do
    :code.all_available()
    |> Enum.filter(fn {mod, _, _} ->
      mod
      |> to_string()
      |> String.starts_with?("Elixir.Pleroma.")
    end)
    |> Enum.map(fn {mod, _, _} ->
      mod
      |> to_string()
      |> String.to_existing_atom()
      |> Code.ensure_loaded!()
    end)

    # Use this when 1.15 is standard
    # |> Code.ensure_all_loaded!()
  end

  defp cachex_children do
    [
      build_cachex(
        "used_captcha",
        expiration: expiration(interval: seconds_valid_interval())
      ),
      build_cachex(
        "user",
        expiration: expiration(default: 3_000, interval: 1_000),
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "object",
        expiration: expiration(default: 3_000, interval: 1_000),
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "rich_media",
        expiration: expiration(default: :timer.hours(2)),
        hooks: [cachex_sched_limit(5000)]
      ),
      build_cachex(
        "scrubber",
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "scrubber_management",
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "idempotency",
        expiration: expiration(default: :timer.hours(6), interval: :timer.minutes(1)),
        hooks: [cachex_sched_limit(2500, [], frequency: :timer.minutes(1))]
      ),
      build_cachex(
        "web_resp",
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "emoji_packs",
        expiration: expiration(default: :timer.minutes(5), interval: :timer.minutes(1)),
        hooks: [cachex_sched_limit(10)]
      ),
      build_cachex(
        "failed_proxy_url",
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "banned_urls",
        expiration: expiration(default: :timer.hours(24 * 30)),
        hooks: [cachex_sched_limit(5_000, [], frequency: :timer.minutes(5))]
      ),
      build_cachex(
        "translations",
        expiration: expiration(default: :timer.hours(24 * 30)),
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "instances",
        expiration: expiration(default: :timer.hours(24), interval: 1000),
        hooks: [cachex_sched_limit(2500)]
      ),
      build_cachex(
        "rel_me",
        expiration: expiration(default: :timer.hours(24 * 30)),
        hooks: [cachex_sched_limit(300, [], frequency: :timer.minutes(1))]
      ),
      build_cachex(
        "host_meta",
        expiration: expiration(default: :timer.minutes(120)),
        hooks: [cachex_sched_limit(5000, [], frequency: :timer.minutes(1))]
      ),
      build_cachex(
        "http_backoff",
        expiration: expiration(default: :timer.hours(24 * 30)),
        hooks: [cachex_sched_limit(10_000, [], frequency: :timer.minutes(5))]
      )
    ]
  end

  defp seconds_valid_interval,
    do: :timer.seconds(Config.get!([Pleroma.Captcha, :seconds_valid]))

  defp cachex_sched_limit(limit, prune_opts \\ [], sched_opts \\ []),
    do: hook(module: Cachex.Limit.Scheduled, args: {limit, prune_opts, sched_opts})

  @spec build_cachex(String.t(), keyword()) :: map()
  def build_cachex(type, opts),
    do: %{
      id: String.to_atom("cachex_" <> type),
      start: {Cachex, :start_link, [String.to_atom(type <> "_cache"), opts]},
      type: :worker
    }

  defp dont_run_in_test(env) when env in [:test, :benchmark], do: []

  defp dont_run_in_test(_) do
    [
      {Registry,
       [
         name: Pleroma.Web.Streamer.registry(),
         keys: :duplicate,
         partitions: System.schedulers_online()
       ]}
    ] ++ background_migrators()
  end

  defp background_migrators do
    [
      Pleroma.Migrators.HashtagsTableMigrator
    ]
  end

  @spec task_children() :: [map()]
  defp task_children() do
    always =
      [
        %{
          id: :web_push_init,
          start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
          restart: :temporary
        }
      ]

    if @mix_env == :test do
      always
    else
      [
        %{
          id: :internal_fetch_init,
          start: {Task, :start_link, [&Pleroma.Web.ActivityPub.InternalFetchActor.init/0]},
          restart: :temporary
        }
        | always
      ]
    end
  end

  @spec elasticsearch_children :: [Pleroma.Search.Elasticsearch.Cluster]
  def elasticsearch_children do
    config = Config.get([Pleroma.Search, :module])

    if config == Pleroma.Search.Elasticsearch do
      [Pleroma.Search.Elasticsearch.Cluster]
    else
      []
    end
  end

  @spec limiters_setup() :: :ok
  def limiters_setup do
    config = Config.get(ConcurrentLimiter, [])

    [
      Pleroma.Web.RichMedia.Helpers,
      Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy,
      Pleroma.Search
    ]
    |> Enum.each(fn module ->
      mod_config = Keyword.get(config, module, [])

      max_running = Keyword.get(mod_config, :max_running, 5)
      max_waiting = Keyword.get(mod_config, :max_waiting, 5)

      ConcurrentLimiter.new(module, max_running, max_waiting)
    end)
  end

  defp http_children do
    :public_key.cacerts_load()

    config =
      Config.get([:http, :adapter])
      |> Pleroma.HTTP.AdapterHelper.options()

    [{Finch, config}]
  end
end
