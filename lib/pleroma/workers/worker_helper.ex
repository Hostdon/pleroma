# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.WorkerHelper do
  alias Pleroma.Config
  alias Pleroma.Workers.WorkerHelper

  def worker_args(queue) do
    case Config.get([:workers, :retries, queue]) do
      nil -> []
      max_attempts -> [max_attempts: max_attempts]
    end
  end

  def sidekiq_backoff(attempt, pow \\ 4, base_backoff \\ 15) do
    backoff =
      :math.pow(attempt, pow) +
        base_backoff +
        :rand.uniform(2 * base_backoff) * attempt

    trunc(backoff)
  end

  defmacro __using__(opts) do
    caller_module = __CALLER__.module
    queue = Keyword.fetch!(opts, :queue)
    # by default just stop unintended duplicates - this can and should be overridden
    # if you want to have a more complex uniqueness constraint
    uniqueness = Keyword.get(opts, :unique, period: 1)

    quote do
      # Note: `max_attempts` is intended to be overridden in `new/2` call
      use Oban.Worker,
        queue: unquote(queue),
        max_attempts: 1,
        unique: unquote(uniqueness)

      alias Oban.Job

      def enqueue(op, params, worker_args \\ []) do
        params = Map.merge(%{"op" => op}, params)
        queue_atom = String.to_atom(unquote(queue))
        worker_args = worker_args ++ WorkerHelper.worker_args(queue_atom)

        unquote(caller_module)
        |> apply(:new, [params, worker_args])
        |> Oban.insert()
      end

      @impl Oban.Worker
      def timeout(_job) do
        queue_atom = String.to_atom(unquote(queue))
        Config.get([:workers, :timeout, queue_atom], :timer.minutes(1))
      end
    end
  end
end
