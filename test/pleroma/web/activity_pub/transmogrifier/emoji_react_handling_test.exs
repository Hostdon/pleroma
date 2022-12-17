# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.EmojiReactHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it works for incoming emoji reactions" do
    user = insert(:user)
    other_user = insert(:user, local: false)
    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    data =
      File.read!("test/fixtures/emoji-reaction.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])
      |> Map.put("actor", other_user.ap_id)

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == other_user.ap_id
    assert data["type"] == "EmojiReact"
    assert data["id"] == "http://mastodon.example.org/users/admin#reactions/2"
    assert data["object"] == activity.data["object"]
    assert data["content"] == "👌"

    object = Object.get_by_ap_id(data["object"])

    assert object.data["reaction_count"] == 1
    assert match?([["👌", _, nil]], object.data["reactions"])
  end

  test "it works for incoming custom emoji reactions" do
    user = insert(:user)
    other_user = insert(:user, local: false)
    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    data =
      File.read!("test/fixtures/custom-emoji-reaction.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])
      |> Map.put("actor", other_user.ap_id)

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == other_user.ap_id
    assert data["type"] == "EmojiReact"
    assert data["id"] == "https://misskey.local.live/likes/917ocsybgp"
    assert data["object"] == activity.data["object"]
    assert data["content"] == ":hanapog:"

    assert data["tag"] == [
             %{
               "id" => "https://misskey.local.live/emojis/hanapog",
               "type" => "Emoji",
               "name" => "hanapog",
               "updated" => "2022-06-07T12:00:05.773Z",
               "icon" => %{
                 "type" => "Image",
                 "url" =>
                   "https://misskey.local.live/files/webpublic-8f8a9768-7264-4171-88d6-2356aabeadcd"
               }
             }
           ]

    object = Object.get_by_ap_id(data["object"])

    assert object.data["reaction_count"] == 1

    assert match?(
             [
               [
                 "hanapog",
                 _,
                 "https://misskey.local.live/files/webpublic-8f8a9768-7264-4171-88d6-2356aabeadcd"
               ]
             ],
             object.data["reactions"]
           )
  end

  test "it works for incoming unqualified emoji reactions" do
    user = insert(:user)
    other_user = insert(:user, local: false)
    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    # woman detective emoji, unqualified
    unqualified_emoji = [0x1F575, 0x200D, 0x2640] |> List.to_string()

    data =
      File.read!("test/fixtures/emoji-reaction.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])
      |> Map.put("actor", other_user.ap_id)
      |> Map.put("content", unqualified_emoji)

    {:ok, %Activity{data: data, local: false}} = Transmogrifier.handle_incoming(data)

    assert data["actor"] == other_user.ap_id
    assert data["type"] == "EmojiReact"
    assert data["id"] == "http://mastodon.example.org/users/admin#reactions/2"
    assert data["object"] == activity.data["object"]
    # woman detective emoji, fully qualified
    emoji = [0x1F575, 0xFE0F, 0x200D, 0x2640, 0xFE0F] |> List.to_string()
    assert data["content"] == emoji

    object = Object.get_by_ap_id(data["object"])

    assert object.data["reaction_count"] == 1
    assert match?([[^emoji, _, _]], object.data["reactions"])
  end

  test "it reject invalid emoji reactions" do
    user = insert(:user)
    other_user = insert(:user, local: false)
    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    data =
      File.read!("test/fixtures/emoji-reaction-too-long.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])
      |> Map.put("actor", other_user.ap_id)

    assert {:error, _} = Transmogrifier.handle_incoming(data)

    data =
      File.read!("test/fixtures/emoji-reaction-no-emoji.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])
      |> Map.put("actor", other_user.ap_id)

    assert {:error, _} = Transmogrifier.handle_incoming(data)
  end
end
