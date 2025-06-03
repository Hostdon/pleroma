# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorker do
  require Logger

  alias Pleroma.Web.Federator

  use Pleroma.Workers.WorkerHelper, queue: "federator_incoming"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "incoming_ap_doc", "params" => params}}) do
    with {:ok, res} <- Federator.perform(:incoming_ap_doc, params) do
      {:ok, res}
    else
      {:error, :origin_containment_failed} ->
        {:discard, :origin_containment_failed}

      {:error, {:reject, reason}} ->
        {:discard, reason}

      {:error, :already_present} ->
        {:discard, :already_present}

      {:error, :ignore} ->
        {:discard, :ignore}

      # invalid data or e.g. deleting an object we don't know about anyway
      {:error, {:validate, issue}} ->
        Logger.info("Received invalid AP document: #{inspect(issue)}")
        {:discard, :invalid}

      # rarer, but sometimes there’s an additional :error in front
      {:error, {:error, {:validate, issue}}} ->
        Logger.info("Received invalid AP document: (2e) #{inspect(issue)}")
        {:discard, :invalid}

      # failed to resolve a necessary referenced remote AP object;
      # might be temporary server/network trouble thus reattempt
      {:error, :link_resolve_failed} = e ->
        Logger.info("Failed to resolve AP link; may retry: #{inspect(params)}")
        e

      {:error, _} = e ->
        Logger.error("Unexpected AP doc error: #{inspect(e)} from #{inspect(params)}")
        e

      e ->
        Logger.error("Unexpected AP doc error: (raw) #{inspect(e)} from #{inspect(params)}")
        {:error, e}
    end
  rescue
    err ->
      Logger.error(
        "Receiver worker CRASH on #{inspect(params)} with: #{Exception.format(:error, err, __STACKTRACE__)}"
      )

      # reraise to let oban handle transaction conflicts without deductig an attempt
      reraise err, __STACKTRACE__
  end
end
