# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.PublisherWorker do
  alias Pleroma.Activity
  alias Pleroma.Web.Federator

  use Pleroma.Workers.WorkerHelper, queue: "federator_outgoing"

  def backoff(%Job{attempt: attempt}) when is_integer(attempt) do
    if attempt > 3 do
      Pleroma.Workers.WorkerHelper.exponential_backoff(attempt, 9.5)
    else
      Pleroma.Workers.WorkerHelper.sidekiq_backoff(attempt, 6)
    end
  end

  @impl Oban.Worker
  def perform(%Job{
        args: %{"op" => "publish", "activity_id" => activity_id, "object_data" => nil}
      }) do
    activity = Activity.get_by_id(activity_id)
    Federator.perform(:publish, activity)
  end

  @impl Oban.Worker
  def perform(%Job{
        args: %{"op" => "publish", "activity_id" => activity_id, "object_data" => object_data}
      }) do
    activity = Activity.get_by_id(activity_id)
    activity = %{activity | data: Map.put(activity.data, "object", Jason.decode!(object_data))}
    Federator.perform(:publish, activity)
  end

  def perform(%Job{args: %{"op" => "publish_one", "module" => module_name, "params" => params}}) do
    res = Federator.perform(:publish_one, String.to_existing_atom(module_name), params)

    case res do
      # instance / actor was explicitly deleted or instance doesn’t support federation
      # either way there’s nothing to retry so just give up
      # Marking instances as unreachable if appropriate is already handled in Publisher module
      {:error, {:http_error, code, _}} when code in [405, 410] ->
        :ok

      res ->
        res
    end
  end
end
