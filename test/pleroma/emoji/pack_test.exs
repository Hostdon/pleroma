# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emoji.PackTest do
  use Pleroma.DataCase, async: false
  alias Pleroma.Emoji
  alias Pleroma.Emoji.Pack

  @static_dir Pleroma.Config.get!([:instance, :static_dir])
  @emoji_path Path.join(
                Pleroma.Config.get!([:instance, :static_dir]),
                "emoji"
              )

  defp sync_emoji_changes() do
    # emoji updates happen asynchronously;
    # force all pending change requests to be processed before checking condition
    # (this is an (afaik undocumented) side-effect of get_state;
    #  presumably due to it doing a sync call to retrieve the state and message queue ordering)
    :sys.get_state(Pleroma.Emoji)
  end

  setup do
    pack_path = Path.join(@emoji_path, "dump_pack")
    File.mkdir_p!(pack_path)
    clear_config([:instance, :static_dir], @static_dir)

    File.write!(Path.join(pack_path, "pack.json"), """
    {
    "files": { },
    "pack": {
    "description": "Dump pack", "homepage": "https://pleroma.social",
    "license": "Test license", "share-files": true
    }}
    """)

    {:ok, pack} = Pleroma.Emoji.Pack.load_pack("dump_pack")

    on_exit(fn ->
      Pack.delete("dump_pack")
    end)

    {:ok, pack: pack}
  end

  describe "add_file/4" do
    test "add emojis from zip file", %{pack: pack} do
      file = %Plug.Upload{
        content_type: "application/zip",
        filename: "emojis.zip",
        path: Path.absname("test/fixtures/emojis.zip")
      }

      {:ok, updated_pack} = Pack.add_file(pack, nil, nil, file)

      assert updated_pack.files == %{
               "a_trusted_friend-128" => "128px/a_trusted_friend-128.png",
               "auroraborealis" => "auroraborealis.png",
               "baby_in_a_box" => "1000px/baby_in_a_box.png",
               "bear" => "1000px/bear.png",
               "bear-128" => "128px/bear-128.png"
             }

      assert updated_pack.files_count == 5
    end
  end

  test "returns error when zip file is bad", %{pack: pack} do
    file = %Plug.Upload{
      content_type: "application/zip",
      filename: "emojis.zip",
      path: Path.absname("test/instance_static/emoji/test_pack/blank.png")
    }

    # this varies by erlang OTP
    possible_error_codes = [:bad_eocd, :einval]
    {:error, code} = Pack.add_file(pack, nil, nil, file)
    assert Enum.member?(possible_error_codes, code)
  end

  test "returns pack when zip file is empty", %{pack: pack} do
    file = %Plug.Upload{
      content_type: "application/zip",
      filename: "emojis.zip",
      path: Path.absname("test/fixtures/empty.zip")
    }

    {:ok, updated_pack} = Pack.add_file(pack, nil, nil, file)
    assert updated_pack == pack
  end

  test "add emoji file", %{pack: pack} do
    file = %Plug.Upload{
      filename: "blank.png",
      path: "#{@emoji_path}/test_pack/blank.png"
    }

    {:ok, updated_pack} = Pack.add_file(pack, "test_blank", "test_blank.png", file)

    assert updated_pack.files == %{
             "test_blank" => "test_blank.png"
           }

    assert updated_pack.files_count == 1

    sync_emoji_changes()

    emoji = Emoji.get("test_blank")
    assert emoji
    assert emoji.file == "/emoji/" <> pack.name <> "/test_blank.png"
  end

  test "update emoji file keeping name", %{pack: pack} do
    file = %Plug.Upload{
      filename: "blank.png",
      path: "#{@emoji_path}/test_pack/blank.png"
    }

    {:ok, pack} = Pack.add_file(pack, "test_blank", "test_blank.png", file)

    {:ok, updated_pack} =
      Pack.update_file(pack, "test_blank", "test_blank", "newblank.webp", true)

    assert updated_pack.files == %{
             "test_blank" => "newblank.webp"
           }

    assert updated_pack.files_count == 1

    sync_emoji_changes()

    emoji = Emoji.get("test_blank")
    assert emoji
    assert emoji.file == "/emoji/" <> pack.name <> "/newblank.webp"
  end

  test "rename emoji", %{pack: pack} do
    file = %Plug.Upload{
      filename: "blank.png",
      path: "#{@emoji_path}/test_pack/blank.png"
    }

    {:ok, pack} = Pack.add_file(pack, "test_blank", "test_blank.png", file)

    {:ok, updated_pack} = Pack.update_file(pack, "test_blank", "blank_ng", "newblank.webp", false)

    assert updated_pack.files == %{
             "blank_ng" => "newblank.webp"
           }

    assert updated_pack.files_count == 1

    sync_emoji_changes()

    refute Emoji.get("test_blank")

    emoji = Emoji.get("blank_ng")
    assert emoji
    assert emoji.file == "/emoji/" <> pack.name <> "/newblank.webp"
  end

  test "load_pack/1 panics on path traversal in a forged pack name" do
    assert_raise(RuntimeError, "Invalid or malicious pack name: ../../../../../dump_pack", fn ->
      Pack.load_pack("../../../../../dump_pack")
    end)
  end
end
