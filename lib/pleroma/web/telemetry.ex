defmodule Pleroma.Web.Telemetry do
  use Supervisor
  import Ecto.Query
  import Telemetry.Metrics
  alias Pleroma.Stats
  alias Pleroma.Config
  require Logger

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    subscribe_to_events()

    children =
      [
        {:telemetry_poller, measurements: periodic_measurements(), period: 60_000}
      ] ++
        prometheus_children()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp prometheus_children do
    config = Config.get([:instance, :export_prometheus_metrics], true)

    if config do
      [
        {TelemetryMetricsPrometheus.Core, metrics: prometheus_metrics()},
        Pleroma.PrometheusExporter
      ]
    else
      []
    end
  end

  defp subscribe_to_events() do
    # note: all handlers for a event are executed blockingly
    # before the event can conclude, so they mustn't do anything heavy
    :telemetry.attach(
      "akkoma-oban-jobs-stop",
      [:oban, :job, :stop],
      &__MODULE__.handle_lib_event/4,
      []
    )

    :telemetry.attach(
      "akkoma-oban-jobs-fail",
      [:oban, :job, :exception],
      &__MODULE__.handle_lib_event/4,
      []
    )
  end

  def handle_lib_event(
        [:oban, :job, event],
        _measurements,
        %{state: :discard, worker: "Pleroma.Workers.PublisherWorker"} = meta,
        _config
      )
      when event in [:stop, :exception] do
    {full_target, simple_target, reason} =
      case meta.args["op"] do
        "publish" ->
          {meta.args["activity_id"], nil, "inbox_collection"}

        "publish_one" ->
          full_inbox = get_in(meta.args, ["params", "inbox"]) || ""
          %{host: simple_target} = URI.parse(full_inbox)
          activity_apid = get_in(meta.args, ["params", "id"]) || "(no AP id)"
          full_target = activity_apid <> " to " <> full_inbox
          error = collect_apdelivery_error(event, meta)
          {full_target, simple_target, error}
      end

    Logger.error("Failed AP delivery: #{inspect(reason)} for #{inspect(full_target)}")

    :telemetry.execute([:akkoma, :ap, :delivery, :fail], %{final: 1}, %{
      reason: reason,
      target: simple_target
    })
  end

  def handle_lib_event([:oban, :job, _], _, _, _), do: :ok

  defp collect_apdelivery_error(:exception, %{result: nil, reason: reason}) do
    case reason do
      %Oban.CrashError{} -> "crash"
      %Oban.TimeoutError{} -> "timeout"
      %type{} -> "exception_#{type}"
    end
  end

  defp collect_apdelivery_error(:exception, %{result: {:error, error}}) do
    process_fail_reason(error)
  end

  defp collect_apdelivery_error(:stop, %{result: {_, reason}}) do
    process_fail_reason(reason)
  end

  defp collect_apdelivery_error(state, res) do
    Logger.info("Unknown AP delivery result: #{inspect(state)}, #{inspect(res)}")
    "cause_unknown"
  end

  defp process_fail_reason(error) do
    case error do
      error when is_binary(error) ->
        error

      error when is_atom(error) ->
        "#{error}"

      {:http_error, reason, _} when is_number(reason) or is_atom(reason) or is_binary(reason) ->
        "http_#{reason}"

      %{status: code} when is_number(code) ->
        "http_#{code}"

      _ ->
        Logger.notice("Unusual AP delivery error mapped to 'unknown': #{inspect(error)}")
        "error_unknown"
    end
  end

  # A seperate set of metrics for distributions because phoenix dashboard does NOT handle them well
  defp distribution_metrics do
    [
      distribution(
        "phoenix.router_dispatch.stop.duration",
        # event_name: [:pleroma, :repo, :query, :total_time],
        measurement: :duration,
        unit: {:native, :second},
        tags: [:route],
        reporter_options: [
          buckets: [0.0005, 0.001, 0.005, 0.01, 0.025, 0.05, 0.10, 0.25, 0.5, 0.75, 1, 2, 5, 15]
        ]
      ),

      # Database Time Metrics
      distribution(
        "pleroma.repo.query.total_time",
        # event_name: [:pleroma, :repo, :query, :total_time],
        measurement: :total_time,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [0.1, 0.2, 0.5, 1, 2.5, 5, 10, 25, 50, 100, 250, 500, 1000]
        ]
      ),
      distribution(
        "pleroma.repo.query.queue_time",
        # event_name: [:pleroma, :repo, :query, :total_time],
        measurement: :queue_time,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1, 2.5, 5, 10]
        ]
      ),
      distribution(
        "oban_job_exception",
        event_name: [:oban, :job, :exception],
        measurement: :duration,
        tags: [:worker],
        tag_values: fn tags -> Map.put(tags, :worker, tags.job.worker) end,
        unit: {:native, :second},
        reporter_options: [
          buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1, 2.5, 5, 10]
        ]
      ),
      distribution(
        "tesla_request_completed",
        event_name: [:tesla, :request, :stop],
        measurement: :duration,
        tags: [:response_code],
        tag_values: fn tags -> Map.put(tags, :response_code, tags.env.status) end,
        unit: {:native, :second},
        reporter_options: [
          buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1, 2.5, 5, 10]
        ]
      ),
      distribution(
        "oban_job_completion",
        event_name: [:oban, :job, :stop],
        measurement: :duration,
        tags: [:worker],
        tag_values: fn tags -> Map.put(tags, :worker, tags.job.worker) end,
        unit: {:native, :second},
        reporter_options: [
          buckets: [0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1, 2.5, 5, 10]
        ]
      )
    ]
  end

  # Summary metrics are currently not (yet) supported by the prometheus exporter
  defp summary_metrics(byte_unit) do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("pleroma.repo.query.total_time", unit: {:native, :millisecond}),
      summary("pleroma.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("pleroma.repo.query.query_time", unit: {:native, :millisecond}),
      summary("pleroma.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("pleroma.repo.query.idle_time", unit: {:native, :millisecond}),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, byte_unit}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp sum_counter_pair(basename, opts) do
    [
      sum(basename <> ".psum", opts),
      counter(basename <> ".pcount", opts)
    ]
  end

  # Prometheus exporter doesn't support summaries, so provide fallbacks
  defp summary_fallback_metrics(byte_unit \\ :byte) do
    # Summary metrics are not supported by the Prometheus exporter
    #   https://github.com/beam-telemetry/telemetry_metrics_prometheus_core/issues/11
    # and sum metrics currently only work with integers
    #   https://github.com/beam-telemetry/telemetry_metrics_prometheus_core/issues/35
    #
    # For VM metrics this is kindof ok as they appear to always be integers
    # and we can use sum + counter to get the average between polls from their change
    # But for repo query times we need to use a full distribution

    simple_buckets = [1, 2, 4, 8, 16, 32]

    # Already included in distribution metrics anyway:
    #   phoenix.router_dispatch.stop.duration
    #   pleroma.repo.query.total_time
    #   pleroma.repo.query.queue_time
    dist_metrics = [
      distribution("phoenix.endpoint.stop.duration.fdist",
        event_name: [:phoenix, :endpoint, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: simple_buckets
        ]
      ),
      distribution("pleroma.repo.query.decode_time.fdist",
        event_name: [:pleroma, :repo, :query],
        measurement: :decode_time,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [0.001, 0.0025, 0.005, 0.01, 0.02, 0.05, 0.1, 0.5]
        ]
      ),
      distribution("pleroma.repo.query.query_time.fdist",
        event_name: [:pleroma, :repo, :query],
        measurement: :query_time,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: [0.1, 0.2, 0.5, 1, 1.5, 3, 5, 10, 25, 50]
        ]
      ),
      distribution("pleroma.repo.query.idle_time.fdist",
        event_name: [:pleroma, :repo, :query],
        measurement: :idle_time,
        unit: {:native, :millisecond},
        reporter_options: [
          buckets: simple_buckets
        ]
      )
    ]

    vm_metrics =
      sum_counter_pair("vm.memory.total",
        event_name: [:vm, :memory],
        measurement: :total,
        unit: {:byte, byte_unit}
      ) ++
        sum_counter_pair("vm.total_run_queue_lengths.total",
          event_name: [:vm, :total_run_queue_lengths],
          measurement: :total
        ) ++
        sum_counter_pair("vm.total_run_queue_lengths.cpu",
          event_name: [:vm, :total_run_queue_lengths],
          measurement: :cpu
        ) ++
        sum_counter_pair("vm.total_run_queue_lengths.io.fsum",
          event_name: [:vm, :total_run_queue_lengths],
          measurement: :io
        )

    dist_metrics ++ vm_metrics
  end

  defp common_metrics(byte_unit \\ :byte) do
    [
      last_value("vm.portio.in.total", unit: {:byte, byte_unit}),
      last_value("vm.portio.out.total", unit: {:byte, byte_unit}),
      last_value("pleroma.local_users.total"),
      last_value("pleroma.domains.total"),
      last_value("pleroma.local_statuses.total"),
      last_value("pleroma.remote_users.total"),
      counter("akkoma.ap.delivery.fail.final", tags: [:target, :reason]),
      last_value("akkoma.job.queue.scheduled", tags: [:queue_name]),
      last_value("akkoma.job.queue.available", tags: [:queue_name]),
      last_value("akkoma.job.queue.retryable", tags: [:queue_name])
    ]
  end

  def prometheus_metrics,
    do: common_metrics() ++ distribution_metrics() ++ summary_fallback_metrics()

  def live_dashboard_metrics, do: common_metrics(:megabyte) ++ summary_metrics(:megabyte)

  defp periodic_measurements do
    [
      {__MODULE__, :io_stats, []},
      {__MODULE__, :instance_stats, []},
      {__MODULE__, :oban_pending, []}
    ]
  end

  def io_stats do
    # All IO done via erlang ports, i.e. mostly network but also e.g. fasthtml_workers. NOT disk IO!
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)
    :telemetry.execute([:vm, :portio, :in], %{total: input}, %{})
    :telemetry.execute([:vm, :portio, :out], %{total: output}, %{})
  end

  def instance_stats do
    stats = Stats.get_stats()
    :telemetry.execute([:pleroma, :local_users], %{total: stats.user_count}, %{})
    :telemetry.execute([:pleroma, :domains], %{total: stats.domain_count}, %{})
    :telemetry.execute([:pleroma, :local_statuses], %{total: stats.status_count}, %{})
    :telemetry.execute([:pleroma, :remote_users], %{total: stats.remote_user_count}, %{})
  end

  def oban_pending() do
    query =
      from(j in Oban.Job,
        select: %{queue: j.queue, state: j.state, count: count()},
        where: j.state in ["scheduled", "available", "retryable"],
        group_by: [j.queue, j.state]
      )

    conf = Oban.Config.new(Config.get!(Oban))
    qres = Oban.Repo.all(conf, query)

    acc =
      Enum.into(conf.queues, %{}, fn {x, _} ->
        {x, %{available: 0, retryable: 0, scheduled: 0}}
      end)

    acc =
      Enum.reduce(qres, acc, fn %{queue: q, state: state, count: count}, acc ->
        put_in(acc, [String.to_existing_atom(q), String.to_existing_atom(state)], count)
      end)

    for {queue, info} <- acc do
      :telemetry.execute([:akkoma, :job, :queue], info, %{queue_name: queue})
    end
  end
end
