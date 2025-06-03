# Akkoma: Magically expressive social media
# Copyright © 2025 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ContentTypeSanitisationTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.ContentTypeSanitisationTemplate, as: Template

  require Template

  defp create_file(path, body) do
    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
  end

  defp upload_dir(),
    do: Path.join(Pleroma.Uploaders.Local.upload_path(), "test_StaticPlugSanitisationTest")

  defp create_upload(subpath, body) do
    Path.join(upload_dir(), subpath)
    |> create_file(body)

    "/media/test_StaticPlugSanitisationTest/#{subpath}"
  end

  defp emoji_dir(),
    do:
      Path.join(
        Pleroma.Config.get!([:instance, :static_dir]),
        "emoji/test_StaticPlugSanitisationTest"
      )

  defp create_emoji(subpath, body) do
    Path.join(emoji_dir(), subpath)
    |> create_file(body)

    "/emoji/test_StaticPlugSanitisationTest/#{subpath}"
  end

  setup_all do
    File.mkdir_p(upload_dir())
    File.mkdir_p(emoji_dir())

    on_exit(fn ->
      File.rm_rf!(upload_dir())
      File.rm_rf!(emoji_dir())
    end)
  end

  describe "sanitises Content-Type of local uploads" do
    Template.do_all_common_tests(&create_upload/2)

    test "while preserving audio types" do
      Template.do_audio_test(&create_upload/2, false)
    end
  end

  describe "sanitises Content-Type of emoji" do
    Template.do_all_common_tests(&create_emoji/2)

    test "if audio type" do
      Template.do_audio_test(&create_emoji/2, true)
    end
  end
end
