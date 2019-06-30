defmodule Pleroma.Upload.Filter.AnonymizeFilenameTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.Upload

  setup do
    custom_filename = Config.get([Upload.Filter.AnonymizeFilename, :text])

    on_exit(fn ->
      Config.put([Upload.Filter.AnonymizeFilename, :text], custom_filename)
    end)

    upload_file = %Upload{
      name: "an… image.jpg",
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image_tmp.jpg")
    }

    %{upload_file: upload_file}
  end

  test "it replaces filename on pre-defined text", %{upload_file: upload_file} do
    Config.put([Upload.Filter.AnonymizeFilename, :text], "custom-file.png")
    {:ok, %Upload{name: name}} = Upload.Filter.AnonymizeFilename.filter(upload_file)
    assert name == "custom-file.png"
  end

  test "it replaces filename on pre-defined text expression", %{upload_file: upload_file} do
    Config.put([Upload.Filter.AnonymizeFilename, :text], "custom-file.{extension}")
    {:ok, %Upload{name: name}} = Upload.Filter.AnonymizeFilename.filter(upload_file)
    assert name == "custom-file.jpg"
  end

  test "it replaces filename on random text", %{upload_file: upload_file} do
    {:ok, %Upload{name: name}} = Upload.Filter.AnonymizeFilename.filter(upload_file)
    assert <<_::bytes-size(14)>> <> ".jpg" = name
    refute name == "an… image.jpg"
  end
end
