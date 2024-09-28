defmodule Pleroma.Web.Telemetry do
  use Supervisor
  import Telemetry.Metrics
  alias Pleroma.Stats
  alias Pleroma.Config

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children =
      [
        {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
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
          buckets: [0.1, 0.2, 0.5, 1, 2.5, 5, 10, 25, 50, 100, 250, 500, 1000]
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

  defp summary_metrics do
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
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      last_value("pleroma.local_users.total"),
      last_value("pleroma.domains.total"),
      last_value("pleroma.local_statuses.total"),
      last_value("pleroma.remote_users.total")
    ]
  end

  def prometheus_metrics, do: summary_metrics() ++ distribution_metrics()
  def live_dashboard_metrics, do: summary_metrics()

  defp periodic_measurements do
    [
      {__MODULE__, :instance_stats, []}
    ]
  end

  def instance_stats do
    stats = Stats.get_stats()
    :telemetry.execute([:pleroma, :local_users], %{total: stats.user_count}, %{})
    :telemetry.execute([:pleroma, :domains], %{total: stats.domain_count}, %{})
    :telemetry.execute([:pleroma, :local_statuses], %{total: stats.status_count}, %{})
    :telemetry.execute([:pleroma, :remote_users], %{total: stats.remote_user_count}, %{})
  end
end
