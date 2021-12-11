# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.ExiftoolTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Upload.Filter

  test "apply exiftool filter" do
    assert Pleroma.Utils.command_available?("exiftool")

    File.cp!(
      "test/fixtures/DSCN0010.jpg",
      "test/fixtures/DSCN0010_tmp.jpg"
    )

    upload = %Pleroma.Upload{
      name: "image_with_GPS_data.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/DSCN0010.jpg"),
      tempfile: Path.absname("test/fixtures/DSCN0010_tmp.jpg")
    }

    assert Filter.Exiftool.filter(upload) == {:ok, :filtered}

    {exif_original, 0} = System.cmd("exiftool", ["test/fixtures/DSCN0010.jpg"])
    {exif_filtered, 0} = System.cmd("exiftool", ["test/fixtures/DSCN0010_tmp.jpg"])

    refute exif_original == exif_filtered
    assert String.match?(exif_original, ~r/GPS/)
    refute String.match?(exif_filtered, ~r/GPS/)
  end

  test "verify webp files are skipped" do
    upload = %Pleroma.Upload{
      name: "sample.webp",
      content_type: "image/webp"
    }

    assert Filter.Exiftool.filter(upload) == {:ok, :noop}
  end
end
