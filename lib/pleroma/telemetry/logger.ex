# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Telemetry.Logger do
  @moduledoc "Transforms Pleroma telemetry events to logs"

  require Logger

  @events [
    [:pleroma, :repo, :query]
  ]
  def attach do
    :telemetry.attach_many(
      "pleroma-logger",
      @events,
      &Pleroma.Telemetry.Logger.handle_event/4,
      []
    )
  end

  # Passing anonymous functions instead of strings to logger is intentional,
  # that way strings won't be concatenated if the message is going to be thrown
  # out anyway due to higher log level configured

  def handle_event(
        [:pleroma, :repo, :query] = _name,
        %{query_time: query_time} = measurements,
        %{source: source} = metadata,
        config
      ) do
    logging_config = Pleroma.Config.get([:telemetry, :slow_queries_logging], [])

    if logging_config[:enabled] &&
         logging_config[:min_duration] &&
         query_time > logging_config[:min_duration] and
         (is_nil(logging_config[:exclude_sources]) or
            source not in logging_config[:exclude_sources]) do
      log_slow_query(measurements, metadata, config)
    else
      :ok
    end
  end

  defp log_slow_query(
         %{query_time: query_time} = _measurements,
         %{source: _source, query: query, params: query_params, repo: repo} = _metadata,
         _config
       ) do
    sql_explain =
      with {:ok, %{rows: explain_result_rows}} <-
             repo.query("EXPLAIN " <> query, query_params, log: false) do
        Enum.map_join(explain_result_rows, "\n", & &1)
      end

    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    pleroma_stacktrace =
      Enum.filter(stacktrace, fn
        {__MODULE__, _, _, _} ->
          false

        {mod, _, _, _} ->
          mod
          |> to_string()
          |> String.starts_with?("Elixir.Pleroma.")
      end)

    Logger.warn(fn ->
      """
      Slow query!

      Total time: #{round(query_time / 1_000)} ms

      #{query}

      #{inspect(query_params, limit: :infinity)}

      #{sql_explain}

      #{Exception.format_stacktrace(pleroma_stacktrace)}
      """
    end)
  end
end
