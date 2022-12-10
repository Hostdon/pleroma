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
    # Disable warnings_as_errors at runtime, it breaks Phoenix live reload
    # due to protocol consolidation warnings
    Code.compiler_options(warnings_as_errors: false)
    Config.Holder.save_default()
    Pleroma.HTML.compile_scrubbers()
    Pleroma.Config.Oban.warn()
    Config.DeprecationWarnings.warn()
    Pleroma.Web.Plugs.HTTPSecurityPlug.warn_if_disabled()
    Pleroma.ApplicationRequirements.verify!()
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
          Pleroma.JobQueueMonitor,
          {Majic.Pool, [name: Pleroma.MajicPool, pool_size: Config.get([:majic_pool, :size], 2)]},
          {Oban, Config.get(Oban)},
          Pleroma.Web.Endpoint
        ] ++
        elasticsearch_children() ++
        task_children(@mix_env) ++
        dont_run_in_test(@mix_env)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    # If we have a lot of caches, default max_restarts can cause test
    # resets to fail.
    # Go for the default 3 unless we're in test
    max_restarts =
      if @mix_env == :test do
        100
      else
        3
      end

    opts = [strategy: :one_for_one, name: Pleroma.Supervisor, max_restarts: max_restarts]

    with {:ok, data} <- Supervisor.start_link(children, opts) do
      set_postgres_server_version()
      {:ok, data}
    else
      e ->
        Logger.error("Failed to start!")
        Logger.error("#{inspect(e)}")
        e
    end
  end

  defp set_postgres_server_version do
    version =
      with %{rows: [[version]]} <- Ecto.Adapters.SQL.query!(Pleroma.Repo, "show server_version"),
           {num, _} <- Float.parse(version) do
        num
      else
        e ->
          Logger.warn(
            "Could not get the postgres version: #{inspect(e)}.\nSetting the default value of 9.6"
          )

          9.6
      end

    :persistent_term.put({Pleroma.Repo, :postgres_version}, version)
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

  defp cachex_children do
    [
      build_cachex("used_captcha", ttl_interval: seconds_valid_interval()),
      build_cachex("user", default_ttl: 25_000, ttl_interval: 1000, limit: 2500),
      build_cachex("object", default_ttl: 25_000, ttl_interval: 1000, limit: 2500),
      build_cachex("rich_media", default_ttl: :timer.minutes(120), limit: 5000),
      build_cachex("scrubber", limit: 2500),
      build_cachex("scrubber_management", limit: 2500),
      build_cachex("idempotency", expiration: idempotency_expiration(), limit: 2500),
      build_cachex("web_resp", limit: 2500),
      build_cachex("emoji_packs", expiration: emoji_packs_expiration(), limit: 10),
      build_cachex("failed_proxy_url", limit: 2500),
      build_cachex("banned_urls", default_ttl: :timer.hours(24 * 30), limit: 5_000),
      build_cachex("translations", default_ttl: :timer.hours(24 * 30), limit: 2500),
      build_cachex("instances", default_ttl: :timer.hours(24), ttl_interval: 1000, limit: 2500),
      build_cachex("request_signatures", default_ttl: :timer.hours(24 * 30), limit: 3000)
    ]
  end

  defp emoji_packs_expiration,
    do: expiration(default: :timer.seconds(5 * 60), interval: :timer.seconds(60))

  defp idempotency_expiration,
    do: expiration(default: :timer.seconds(6 * 60 * 60), interval: :timer.seconds(60))

  defp seconds_valid_interval,
    do: :timer.seconds(Config.get!([Pleroma.Captcha, :seconds_valid]))

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

  defp task_children(:test) do
    [
      %{
        id: :web_push_init,
        start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
        restart: :temporary
      }
    ]
  end

  defp task_children(_) do
    [
      %{
        id: :web_push_init,
        start: {Task, :start_link, [&Pleroma.Web.Push.init/0]},
        restart: :temporary
      },
      %{
        id: :internal_fetch_init,
        start: {Task, :start_link, [&Pleroma.Web.ActivityPub.InternalFetchActor.init/0]},
        restart: :temporary
      }
    ]
  end

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
    proxy_url = Config.get([:http, :proxy_url])
    proxy = Pleroma.HTTP.AdapterHelper.format_proxy(proxy_url)

    config =
      [:http, :adapter]
      |> Config.get([])
      |> Pleroma.HTTP.AdapterHelper.maybe_add_proxy_pool(proxy)
      |> Keyword.put(:name, MyFinch)

    [{Finch, config}]
  end
end
