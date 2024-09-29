# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.StealEmojiPolicyTest do
  use Pleroma.DataCase, async: false

  alias Pleroma.Config
  alias Pleroma.Emoji
  alias Pleroma.Emoji.Pack
  alias Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy

  defp has_pack?() do
    case Pack.load_pack("stolen") do
      {:ok, _pack} -> true
      {:error, :enoent} -> false
    end
  end

  defp has_emoji?(shortcode) do
    case Pack.load_pack("stolen") do
      {:ok, pack} -> Map.has_key?(pack.files, shortcode)
      {:error, :enoent} -> false
    end
  end

  defmacro mock_tesla(
             url \\ "https://example.org/emoji/firedfox.png",
             status \\ 200,
             headers \\ [],
             get_body \\ File.read!("test/fixtures/image.jpg")
           ) do
    quote do
      Tesla.Mock.mock(fn
        %{method: :head, url: unquote(url)} ->
          %Tesla.Env{
            status: unquote(status),
            body: nil,
            url: unquote(url),
            headers: unquote(headers)
          }

        %{method: :get, url: unquote(url)} ->
          %Tesla.Env{
            status: unquote(status),
            body: unquote(get_body),
            url: unquote(url),
            headers: unquote(headers)
          }
      end)
    end
  end

  setup do
    clear_config(:mrf_steal_emoji,
      hosts: ["example.org"],
      size_limit: 284_468,
      download_unknown_size: true
    )

    emoji_path = [:instance, :static_dir] |> Config.get() |> Path.join("emoji/stolen")

    emoji_base_path = [:instance, :static_dir] |> Config.get() |> Path.join("emoji/")
    File.mkdir_p(emoji_base_path)

    Emoji.reload()

    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"firedfox", "https://example.org/emoji/firedfox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    on_exit(fn ->
      File.rm_rf!(emoji_path)
    end)

    [message: message]
  end

  test "does nothing by default", %{message: message} do
    refute "firedfox" in installed()

    clear_config(:mrf_steal_emoji, [])
    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "Steals emoji on unknown shortcode from allowed remote host", %{
    message: message
  } do
    refute "firedfox" in installed()
    refute has_pack?()

    mock_tesla()

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "firedfox" in installed()
    assert has_pack?()

    assert has_emoji?("firedfox")
  end

  test "rejects invalid shortcodes" do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fired/fox", "https://example.org/emoji/firedfox"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    mock_tesla()

    refute "firedfox" in installed()
    refute has_pack?()

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "fired/fox" in installed()
    refute has_emoji?("fired/fox")
  end

  test "prefers content-type header for extension" do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"firedfox", "https://example.org/emoji/firedfox.fud"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    mock_tesla("https://example.org/emoji/firedfox.fud", 200, [{"content-type", "image/gif"}])

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "firedfox" in installed()
    assert has_emoji?("firedfox")
  end

  test "reject regex shortcode", %{message: message} do
    refute "firedfox" in installed()

    clear_config([:mrf_steal_emoji, :rejected_shortcodes], [~r/firedfox/])

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "reject string shortcode", %{message: message} do
    refute "firedfox" in installed()

    clear_config([:mrf_steal_emoji, :rejected_shortcodes], ["firedfox"])

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "reject if size is above the limit", %{message: message} do
    refute "firedfox" in installed()

    mock_tesla()

    clear_config([:mrf_steal_emoji, :size_limit], 50_000)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "reject if host returns error", %{message: message} do
    refute "firedfox" in installed()

    mock_tesla("https://example.org/emoji/firedfox.png", 404, [], "Not found")

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:ok, _message} = StealEmojiPolicy.filter(message)
    end) =~ "MRF.StealEmojiPolicy: Failed to fetch https://example.org/emoji/firedfox.png"

    refute "firedfox" in installed()
  end

  test "reject unknown size", %{message: message} do
    clear_config([:mrf_steal_emoji, :download_unknown_size], false)
    mock_tesla()

    refute "firedfox" in installed()

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:ok, _message} = StealEmojiPolicy.filter(message)
    end) =~
      "MRF.StealEmojiPolicy: Failed to fetch https://example.org/emoji/firedfox.png: {:remote_size, false}"

    refute "firedfox" in installed()
  end

  test "reject too large content-size before download", %{message: message} do
    clear_config([:mrf_steal_emoji, :download_unknown_size], false)
    mock_tesla("https://example.org/emoji/firedfox.png", 200, [{"content-length", 2 ** 30}])

    refute "firedfox" in installed()

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:ok, _message} = StealEmojiPolicy.filter(message)
    end) =~
      "MRF.StealEmojiPolicy: Failed to fetch https://example.org/emoji/firedfox.png: {:remote_size, false}"

    refute "firedfox" in installed()
  end

  test "accepts content-size below limit", %{message: message} do
    clear_config([:mrf_steal_emoji, :download_unknown_size], false)
    mock_tesla("https://example.org/emoji/firedfox.png", 200, [{"content-length", 2}])

    refute "firedfox" in installed()

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "firedfox" in installed()
  end

  defp installed, do: Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
end
