# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

os_exclude = if :os.type() == {:unix, :darwin}, do: [skip_on_mac: true], else: []

ExUnit.start(
  capture_log: true,
  exclude: [:federated, :erratic] ++ os_exclude
)

Mneme.start()
Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, :manual)

{:ok, _} = Application.ensure_all_started(:ex_machina)

# Prepare and later automatically cleanup upload dir
uploads_dir = Pleroma.Config.get([Pleroma.Uploaders.Local, :uploads], "test/uploads")
File.mkdir_p!(uploads_dir)

ExUnit.after_suite(fn _results ->
  uploads = Pleroma.Config.get([Pleroma.Uploaders.Local, :uploads], "test/uploads")
  File.rm_rf!(uploads)
end)

defmodule Pleroma.Test.StaticConfig do
  @moduledoc """
  This module provides a Config that is completely static, built at startup time from the environment. It's safe to use in testing as it will not modify any state.
  """

  @behaviour Pleroma.Config.Getting
  @config Application.get_all_env(:pleroma)

  def get(path, default \\ nil) do
    get_in(@config, path) || default
  end
end
