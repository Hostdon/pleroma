# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.BuilderTest do
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.CommonAPI.ActivityDraft
  use Pleroma.DataCase

  import Pleroma.Factory

  describe "note/1" do
    test "returns note data" do
      user = insert(:user)
      note = insert(:note)
      quote = insert(:note)
      user2 = insert(:user)
      user3 = insert(:user)

      draft = %ActivityDraft{
        user: user,
        to: [user2.ap_id],
        context: "2hu",
        content_html: "<h1>This is :moominmamma: note</h1>",
        in_reply_to: note.id,
        tags: [name: "jimm"],
        summary: "test summary",
        cc: [user3.ap_id],
        extra: %{"custom_tag" => "test"},
        quote: quote
      }

      expected = %{
        "actor" => user.ap_id,
        "attachment" => [],
        "cc" => [user3.ap_id],
        "content" => "<h1>This is :moominmamma: note</h1>",
        "context" => "2hu",
        "sensitive" => false,
        "summary" => "test summary",
        "tag" => ["jimm"],
        "to" => [user2.ap_id],
        "type" => "Note",
        "custom_tag" => "test",
        "quoteUri" => quote.data["id"]
      }

      assert {:ok, ^expected, []} = Builder.note(draft)
    end
  end

  describe "emoji_react/1" do
    test "unicode emoji" do
      user = insert(:user)
      note = insert(:note)

      assert {:ok, %{"content" => "👍", "type" => "EmojiReact"}, []} =
               Builder.emoji_react(user, note, "👍")
    end

    test "custom emoji" do
      user = insert(:user)
      note = insert(:note)

      assert {:ok,
              %{
                "content" => ":dinosaur:",
                "type" => "EmojiReact",
                "tag" => [
                  %{
                    "name" => ":dinosaur:",
                    "id" => "http://localhost:4001/emoji/dino walking.gif",
                    "icon" => %{
                      "type" => "Image",
                      "url" => "http://localhost:4001/emoji/dino walking.gif"
                    }
                  }
                ]
              }, []} = Builder.emoji_react(user, note, ":dinosaur:")
    end

    test "remote custom emoji" do
      user = insert(:user)
      other_user = insert(:user, local: false)

      note =
        insert(:note,
          data: %{"reactions" => [["wow", [other_user.ap_id], "https://remote/emoji/wow"]]}
        )

      assert {:ok,
              %{
                "content" => ":wow:",
                "type" => "EmojiReact",
                "tag" => [
                  %{
                    "name" => ":wow:",
                    "id" => "https://remote/emoji/wow",
                    "icon" => %{
                      "type" => "Image",
                      "url" => "https://remote/emoji/wow"
                    }
                  }
                ]
              }, []} = Builder.emoji_react(user, note, ":wow@remote:")
    end
  end
end
