# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

os_exclude = if :os.type() == {:unix, :darwin}, do: [skip_on_mac: true], else: []
ExUnit.start(exclude: [:federated, :erratic] ++ os_exclude)

Ecto.Adapters.SQL.Sandbox.mode(Pleroma.Repo, :manual)

{:ok, _} = Application.ensure_all_started(:ex_machina)

# Prepare and later automatically cleanup upload dir
uploads_dir = Pleroma.Config.get([Pleroma.Uploaders.Local, :uploads], "test/uploads")
File.mkdir_p!(uploads_dir)

ExUnit.after_suite(fn _results ->
  uploads = Pleroma.Config.get([Pleroma.Uploaders.Local, :uploads], "test/uploads")
  File.rm_rf!(uploads)
end)
