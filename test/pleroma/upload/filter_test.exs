# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.FilterTest do
  use Pleroma.DataCase

  alias Pleroma.Upload.Filter

  setup do: clear_config([Pleroma.Upload.Filter.AnonymizeFilename, :text])

  test "applies filters" do
    clear_config([Pleroma.Upload.Filter.AnonymizeFilename, :text], "custom-file.png")

    File.cp!(
      "test/fixtures/image.jpg",
      "test/fixtures/image_tmp.jpg"
    )

    upload = %Pleroma.Upload{
      name: "an… image.jpg",
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image_tmp.jpg"),
      tempfile: Path.absname("test/fixtures/image_tmp.jpg")
    }

    assert Filter.filter([], upload) == {:ok, upload}

    assert {:ok, upload} = Filter.filter([Pleroma.Upload.Filter.AnonymizeFilename], upload)
    assert upload.name == "custom-file.png"
  end
end
