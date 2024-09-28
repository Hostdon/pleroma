defmodule Pleroma.PrometheusExporter do
  @moduledoc """
  Exports metrics in Prometheus format.
  Mostly exists because of https://github.com/beam-telemetry/telemetry_metrics_prometheus_core/issues/52
  Basically we need to fetch metrics every so often, or the lib will let them pile up and eventually crash the VM.
  It also sorta acts as a cache so there is that too.
  """

  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_opts) do
    schedule_next()
    {:ok, ""}
  end

  defp schedule_next do
    Process.send_after(self(), :gather, 60_000)
  end

  # Scheduled function, gather metrics and schedule next run
  def handle_info(:gather, _state) do
    schedule_next()
    state = TelemetryMetricsPrometheus.Core.scrape()
    {:noreply, state}
  end

  # Trigger the call dynamically, mostly for testing
  def handle_call(:gather, _from, _state) do
    state = TelemetryMetricsPrometheus.Core.scrape()
    {:reply, state, state}
  end

  def handle_call(:show, _from, state) do
    {:reply, state, state}
  end

  def show do
    GenServer.call(__MODULE__, :show)
  end

  def gather do
    GenServer.call(__MODULE__, :gather)
  end
end
