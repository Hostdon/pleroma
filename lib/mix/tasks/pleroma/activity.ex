# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Activity do
  alias Pleroma.Activity
  require Logger
  import Mix.Pleroma
  use Mix.Task

  @shortdoc "A collection of activity debug tasks"
  @moduledoc """
   A collection of activity related tasks

   mix pleroma.activity get <id>
  """
  def run(["get", id | _rest]) do
    start_pleroma()
    id
    |> Activity.get_by_id()
    |> IO.inspect()
  end
end
