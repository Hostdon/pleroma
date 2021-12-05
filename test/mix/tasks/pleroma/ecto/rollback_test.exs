# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Ecto.RollbackTest do
  use Pleroma.DataCase, async: true
  import ExUnit.CaptureLog
  require Logger

  test "ecto.rollback info message" do
    level = Logger.level()
    Logger.configure(level: :warn)

    assert capture_log(fn ->
             Mix.Tasks.Pleroma.Ecto.Rollback.run(["--env", "test"])
           end) =~ "[info] Rollback succesfully"

    Logger.configure(level: level)
  end
end
