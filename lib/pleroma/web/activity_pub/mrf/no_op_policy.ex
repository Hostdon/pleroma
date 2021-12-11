# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoOpPolicy do
  @moduledoc "Does nothing (lets the messages go through unmodified)"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def filter(object) do
    {:ok, object}
  end

  @impl true
  def describe, do: {:ok, %{}}
end
