# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorker do
  alias Pleroma.Web.Federator

  use Pleroma.Workers.WorkerHelper, queue: "federator_incoming"

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "incoming_ap_doc", "params" => params}}) do
    Federator.perform(:incoming_ap_doc, params)
  end
end
