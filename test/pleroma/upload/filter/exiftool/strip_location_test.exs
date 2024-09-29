# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool.StripMetadataTest do
  use Pleroma.DataCase
  alias Pleroma.Upload.Filter

  @tag :tmp_dir
  test "exiftool strip metadata strips GPS etc but preserves Orientation and ColorSpace by default",
       %{tmp_dir: tmp_dir} do
    assert Pleroma.Utils.command_available?("exiftool")

    tmpfile = Path.join(tmp_dir, "tmp.jpg")

    File.cp!(
      "test/fixtures/DSCN0010.jpg",
      tmpfile
    )

    upload = %Pleroma.Upload{
      name: "image_with_GPS_data.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/DSCN0010.jpg"),
      tempfile: Path.absname(tmpfile)
    }

    assert Filter.Exiftool.StripMetadata.filter(upload) == {:ok, :filtered}

    exif_original = read_exif("test/fixtures/DSCN0010.jpg")
    exif_filtered = read_exif(tmpfile)

    refute exif_original == exif_filtered
    assert String.match?(exif_original, ~r/GPS/)
    refute String.match?(exif_filtered, ~r/GPS/)
    assert String.match?(exif_original, ~r/Camera Model Name/)
    refute String.match?(exif_filtered, ~r/Camera Model Name/)
    assert String.match?(exif_original, ~r/Orientation/)
    assert String.match?(exif_filtered, ~r/Orientation/)
    assert String.match?(exif_original, ~r/Color Space/)
    assert String.match?(exif_filtered, ~r/Color Space/)
  end

  # this is a nonsensical configuration, but it shouldn't explode
  @tag :tmp_dir
  test "exiftool strip metadata is a noop with empty purge list", %{tmp_dir: tmp_dir} do
    assert Pleroma.Utils.command_available?("exiftool")
    clear_config([Pleroma.Upload.Filter.Exiftool.StripMetadata, :purge], [])

    tmpfile = Path.join(tmp_dir, "tmp.jpg")

    File.cp!(
      "test/fixtures/DSCN0010.jpg",
      tmpfile
    )

    upload = %Pleroma.Upload{
      name: "image_with_GPS_data.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/DSCN0010.jpg"),
      tempfile: Path.absname(tmpfile)
    }

    assert Filter.Exiftool.StripMetadata.filter(upload) == {:ok, :filtered}

    exif_original = read_exif("test/fixtures/DSCN0010.jpg")
    exif_filtered = read_exif(tmpfile)

    assert exif_original == exif_filtered
  end

  @tag :tmp_dir
  test "exiftool strip metadata works with empty preserve list", %{tmp_dir: tmp_dir} do
    assert Pleroma.Utils.command_available?("exiftool")
    clear_config([Pleroma.Upload.Filter.Exiftool.StripMetadata, :preserve], [])

    tmpfile = Path.join(tmp_dir, "tmp.jpg")

    File.cp!(
      "test/fixtures/DSCN0010.jpg",
      tmpfile
    )

    upload = %Pleroma.Upload{
      name: "image_with_GPS_data.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/DSCN0010.jpg"),
      tempfile: Path.absname(tmpfile)
    }

    write_exif(["-ImageDescription=Trees and Houses", "-Orientation=1", tmpfile])
    exif_extended = read_exif(tmpfile)
    assert String.match?(exif_extended, ~r/Image Description[ \t]*:[ \t]*Trees and Houses/)
    assert String.match?(exif_extended, ~r/Orientation/)

    assert Filter.Exiftool.StripMetadata.filter(upload) == {:ok, :filtered}

    exif_original = read_exif("test/fixtures/DSCN0010.jpg")
    exif_filtered = read_exif(tmpfile)

    refute exif_original == exif_filtered
    refute exif_extended == exif_filtered
    assert String.match?(exif_original, ~r/GPS/)
    refute String.match?(exif_filtered, ~r/GPS/)
    refute String.match?(exif_filtered, ~r/Image Description/)
    refute String.match?(exif_filtered, ~r/Orientation/)
  end

  test "verify webp files are skipped" do
    upload = %Pleroma.Upload{
      name: "sample.webp",
      content_type: "image/webp"
    }

    assert Filter.Exiftool.StripMetadata.filter(upload) == {:ok, :noop}
  end

  test "verify svg files are skipped" do
    upload = %Pleroma.Upload{
      name: "sample.svg",
      content_type: "image/svg+xml"
    }

    assert Filter.Exiftool.StripMetadata.filter(upload) == {:ok, :noop}
  end

  defp read_exif(file) do
    # time and file path tags cause mismatches even for byte-identical files
    {exif_data, 0} =
      System.cmd("exiftool", [
        "-x",
        "Time:All",
        "-x",
        "Directory",
        "-x",
        "FileName",
        "-x",
        "FileSize",
        file
      ])

    exif_data
  end

  defp write_exif(args) do
    {_response, 0} = System.cmd("exiftool", ["-ignoreMinorErrors", "-overwrite_original" | args])
  end
end
