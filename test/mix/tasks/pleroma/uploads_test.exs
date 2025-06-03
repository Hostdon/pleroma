# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.UploadsTest do
  alias Pleroma.Upload
  use Pleroma.DataCase, async: false
  @moduletag :mocked

  import Mock

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  setup do: clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)

  describe "running migrate_local" do
    test "uploads migrated" do
      File.copy!("test/fixtures/video.mp4", "test/uploads/video.mp4")

      with_mock Upload,
        store: fn %Upload{name: _file, path: _path}, _opts -> {:ok, %{}} end do
        Mix.Tasks.Pleroma.Uploads.run(["migrate_local", "S3"])

        assert_receive {:mix_shell, :info, [message]}, 1_000
        assert message =~ "Migrating files from local"

        assert_receive {:mix_shell, :info, [message]}, 1_000

        assert %{"total_count" => total_count} =
                 Regex.named_captures(~r"^Found (?<total_count>\d+) uploads$", message)

        assert_receive {:mix_shell, :info, [message]}, 1_000

        count =
          min(50, String.to_integer(total_count))
          |> to_string()

        assert %{"count" => ^count, "total_count" => ^total_count} =
                 Regex.named_captures(
                   ~r"^Uploaded (?<count>\d+)/(?<total_count>\d+) files$",
                   message
                 )
      end
    end

    test "nonexistent uploader" do
      assert_raise RuntimeError, ~r/The uploader .* is not an existing/, fn ->
        Mix.Tasks.Pleroma.Uploads.run(["migrate_local", "nonexistent"])
      end
    end
  end
end
