# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.DropPolicy do
  require Logger
  @moduledoc "Drop and log everything received"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(object) do
    Logger.debug("REJECTING #{inspect(object)}")
    {:reject, object}
  end

  @impl true
  def describe, do: {:ok, %{}}
end
