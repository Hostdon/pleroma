# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.UtilsTest do
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  use Pleroma.DataCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  @public_address "https://www.w3.org/ns/activitystreams#Public"

  describe "add_attachments/2" do
    setup do
      name =
        "Sakura Mana – Turned on by a Senior OL with a Temptating Tight Skirt-s Full Hipline and Panty Shot- Beautiful Thick Thighs- and Erotic Ass- -2015- -- Oppaitime 8-28-2017 6-50-33 PM.png"

      attachment = %{
        "url" => [%{"href" => URI.encode(name)}]
      }

      %{name: name, attachment: attachment}
    end

    test "it adds attachment links to a given text and attachment set", %{
      name: name,
      attachment: attachment
    } do
      len = 10
      clear_config([Pleroma.Upload, :filename_display_max_length], len)

      expected =
        "<br><a href=\"#{URI.encode(name)}\" class='attachment'>#{String.slice(name, 0..len)}…</a>"

      assert Utils.add_attachments("", [attachment]) == expected
    end

    test "doesn't truncate file name if config for truncate is set to 0", %{
      name: name,
      attachment: attachment
    } do
      clear_config([Pleroma.Upload, :filename_display_max_length], 0)

      expected = "<br><a href=\"#{URI.encode(name)}\" class='attachment'>#{name}</a>"

      assert Utils.add_attachments("", [attachment]) == expected
    end
  end

  describe "it confirms the password given is the current users password" do
    test "incorrect password given" do
      {:ok, user} = UserBuilder.insert()

      assert Utils.confirm_current_password(user, "") == {:error, "Invalid password."}
    end

    test "correct password given" do
      {:ok, user} = UserBuilder.insert()
      assert Utils.confirm_current_password(user, "test") == {:ok, user}
    end
  end

  describe "format_input/3" do
    test "works for bare text/plain" do
      text = "hello world!"
      expected = "hello world!"

      {output, [], []} = Utils.format_input(text, "text/plain")

      assert output == expected

      text = "hello world!\n\nsecond paragraph!"
      expected = "hello world!<br><br>second paragraph!"

      {output, [], []} = Utils.format_input(text, "text/plain")

      assert output == expected
    end

    test "works for bare text/html" do
      text = "<p>hello world!</p>"
      expected = "<p>hello world!</p>"

      {output, [], []} = Utils.format_input(text, "text/html")

      assert output == expected

      text = "<p>hello world!</p><br/>\n<p>second paragraph</p>"
      expected = "<p>hello world!</p><br/>\n<p>second paragraph</p>"

      {output, [], []} = Utils.format_input(text, "text/html")

      assert output == expected
    end

    test "works for bare text/markdown" do
      text = "**hello world**"
      expected = "<p><strong>hello world</strong></p>"

      {output, [], []} = Utils.format_input(text, "text/markdown")

      assert output == expected

      text = "**hello world**\n\n*another paragraph*"
      expected = "<p><strong>hello world</strong></p><p><em>another paragraph</em></p>"

      {output, [], []} = Utils.format_input(text, "text/markdown")

      assert output == expected

      text = """
      > cool quote

      by someone
      """

      expected = "<blockquote><p>cool quote</p></blockquote><p>by someone</p>"

      {output, [], []} = Utils.format_input(text, "text/markdown")

      assert output == expected
    end

    test "works for bare text/bbcode" do
      text = "[b]hello world[/b]"
      expected = "<strong>hello world</strong>"

      {output, [], []} = Utils.format_input(text, "text/bbcode")

      assert output == expected

      text = "[b]hello world![/b]\n\nsecond paragraph!"
      expected = "<strong>hello world!</strong><br><br>second paragraph!"

      {output, [], []} = Utils.format_input(text, "text/bbcode")

      assert output == expected

      text = "[b]hello world![/b]\n\n<strong>second paragraph!</strong>"

      expected =
        "<strong>hello world!</strong><br><br>&lt;strong&gt;second paragraph!&lt;/strong&gt;"

      {output, [], []} = Utils.format_input(text, "text/bbcode")

      assert output == expected
    end

    test "works for text/markdown with mentions" do
      {:ok, user} =
        UserBuilder.insert(%{nickname: "user__test", ap_id: "http://foo.com/user__test"})

      text = "**hello world**\n\n*another @user__test and @user__test google.com paragraph*"

      {output, _, _} = Utils.format_input(text, "text/markdown")

      assert output ==
               ~s(<p><strong>hello world</strong></p><p><em>another <span class="h-card"><a class="u-url mention" data-user="#{
                 user.id
               }" href="http://foo.com/user__test" rel="ugc">@<span>user__test</span></a></span> and <span class="h-card"><a class="u-url mention" data-user="#{
                 user.id
               }" href="http://foo.com/user__test" rel="ugc">@<span>user__test</span></a></span> <a href="http://google.com" rel="ugc">google.com</a> paragraph</em></p>)
    end
  end

  describe "context_to_conversation_id" do
    test "creates a mapping object" do
      conversation_id = Utils.context_to_conversation_id("random context")
      object = Object.get_by_ap_id("random context")

      assert conversation_id == object.id
    end

    test "returns an existing mapping for an existing object" do
      {:ok, object} = Object.context_mapping("random context") |> Repo.insert()
      conversation_id = Utils.context_to_conversation_id("random context")

      assert conversation_id == object.id
    end
  end

  describe "formats date to asctime" do
    test "when date is in ISO 8601 format" do
      date = DateTime.utc_now() |> DateTime.to_iso8601()

      expected =
        date
        |> DateTime.from_iso8601()
        |> elem(1)
        |> Calendar.Strftime.strftime!("%a %b %d %H:%M:%S %z %Y")

      assert Utils.date_to_asctime(date) == expected
    end

    test "when date is a binary in wrong format" do
      date = DateTime.utc_now()

      expected = ""

      assert capture_log(fn ->
               assert Utils.date_to_asctime(date) == expected
             end) =~ "[warn] Date #{date} in wrong format, must be ISO 8601"
    end

    test "when date is a Unix timestamp" do
      date = DateTime.utc_now() |> DateTime.to_unix()

      expected = ""

      assert capture_log(fn ->
               assert Utils.date_to_asctime(date) == expected
             end) =~ "[warn] Date #{date} in wrong format, must be ISO 8601"
    end

    test "when date is nil" do
      expected = ""

      assert capture_log(fn ->
               assert Utils.date_to_asctime(nil) == expected
             end) =~ "[warn] Date  in wrong format, must be ISO 8601"
    end

    test "when date is a random string" do
      assert capture_log(fn ->
               assert Utils.date_to_asctime("foo") == ""
             end) =~ "[warn] Date foo in wrong format, must be ISO 8601"
    end
  end

  describe "get_to_and_cc" do
    test "for public posts, not a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, nil, "public", nil)

      assert length(to) == 2
      assert length(cc) == 1

      assert @public_address in to
      assert mentioned_user.ap_id in to
      assert user.follower_address in cc
    end

    test "for public posts, a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      third_user = insert(:user)
      {:ok, activity} = CommonAPI.post(third_user, %{status: "uguu"})
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, activity, "public", nil)

      assert length(to) == 3
      assert length(cc) == 1

      assert @public_address in to
      assert mentioned_user.ap_id in to
      assert third_user.ap_id in to
      assert user.follower_address in cc
    end

    test "for unlisted posts, not a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, nil, "unlisted", nil)

      assert length(to) == 2
      assert length(cc) == 1

      assert @public_address in cc
      assert mentioned_user.ap_id in to
      assert user.follower_address in to
    end

    test "for unlisted posts, a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      third_user = insert(:user)
      {:ok, activity} = CommonAPI.post(third_user, %{status: "uguu"})
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, activity, "unlisted", nil)

      assert length(to) == 3
      assert length(cc) == 1

      assert @public_address in cc
      assert mentioned_user.ap_id in to
      assert third_user.ap_id in to
      assert user.follower_address in to
    end

    test "for private posts, not a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, nil, "private", nil)
      assert length(to) == 2
      assert Enum.empty?(cc)

      assert mentioned_user.ap_id in to
      assert user.follower_address in to
    end

    test "for private posts, a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      third_user = insert(:user)
      {:ok, activity} = CommonAPI.post(third_user, %{status: "uguu"})
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, activity, "private", nil)

      assert length(to) == 2
      assert Enum.empty?(cc)

      assert mentioned_user.ap_id in to
      assert user.follower_address in to
    end

    test "for direct posts, not a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, nil, "direct", nil)

      assert length(to) == 1
      assert Enum.empty?(cc)

      assert mentioned_user.ap_id in to
    end

    test "for direct posts, a reply" do
      user = insert(:user)
      mentioned_user = insert(:user)
      third_user = insert(:user)
      {:ok, activity} = CommonAPI.post(third_user, %{status: "uguu"})
      mentions = [mentioned_user.ap_id]

      {to, cc} = Utils.get_to_and_cc(user, mentions, activity, "direct", nil)

      assert length(to) == 1
      assert Enum.empty?(cc)

      assert mentioned_user.ap_id in to

      {:ok, direct_activity} = CommonAPI.post(third_user, %{status: "uguu", visibility: "direct"})

      {to, cc} = Utils.get_to_and_cc(user, mentions, direct_activity, "direct", nil)

      assert length(to) == 2
      assert Enum.empty?(cc)

      assert mentioned_user.ap_id in to
      assert third_user.ap_id in to
    end
  end

  describe "to_master_date/1" do
    test "removes microseconds from date (NaiveDateTime)" do
      assert Utils.to_masto_date(~N[2015-01-23 23:50:07.123]) == "2015-01-23T23:50:07.000Z"
    end

    test "removes microseconds from date (String)" do
      assert Utils.to_masto_date("2015-01-23T23:50:07.123Z") == "2015-01-23T23:50:07.000Z"
    end

    test "returns empty string when date invalid" do
      assert Utils.to_masto_date("2015-01?23T23:50:07.123Z") == ""
    end
  end

  describe "conversation_id_to_context/1" do
    test "returns id" do
      object = insert(:note)
      assert Utils.conversation_id_to_context(object.id) == object.data["id"]
    end

    test "returns error if object not found" do
      assert Utils.conversation_id_to_context("123") == {:error, "No such conversation"}
    end
  end

  describe "maybe_notify_mentioned_recipients/2" do
    test "returns recipients when activity is not `Create`" do
      activity = insert(:like_activity)
      assert Utils.maybe_notify_mentioned_recipients(["test"], activity) == ["test"]
    end

    test "returns recipients from tag" do
      user = insert(:user)

      object =
        insert(:note,
          user: user,
          data: %{
            "tag" => [
              %{"type" => "Hashtag"},
              "",
              %{"type" => "Mention", "href" => "https://testing.pleroma.lol/users/lain"},
              %{"type" => "Mention", "href" => "https://shitposter.club/user/5381"},
              %{"type" => "Mention", "href" => "https://shitposter.club/user/5381"}
            ]
          }
        )

      activity = insert(:note_activity, user: user, note: object)

      assert Utils.maybe_notify_mentioned_recipients(["test"], activity) == [
               "test",
               "https://testing.pleroma.lol/users/lain",
               "https://shitposter.club/user/5381"
             ]
    end

    test "returns recipients when object is map" do
      user = insert(:user)
      object = insert(:note, user: user)

      activity =
        insert(:note_activity,
          user: user,
          note: object,
          data_attrs: %{
            "object" => %{
              "tag" => [
                %{"type" => "Hashtag"},
                "",
                %{"type" => "Mention", "href" => "https://testing.pleroma.lol/users/lain"},
                %{"type" => "Mention", "href" => "https://shitposter.club/user/5381"},
                %{"type" => "Mention", "href" => "https://shitposter.club/user/5381"}
              ]
            }
          }
        )

      Pleroma.Repo.delete(object)

      assert Utils.maybe_notify_mentioned_recipients(["test"], activity) == [
               "test",
               "https://testing.pleroma.lol/users/lain",
               "https://shitposter.club/user/5381"
             ]
    end

    test "returns recipients when object not found" do
      user = insert(:user)
      object = insert(:note, user: user)

      activity = insert(:note_activity, user: user, note: object)
      Pleroma.Repo.delete(object)

      obj_url = activity.data["object"]

      Tesla.Mock.mock(fn
        %{method: :get, url: ^obj_url} ->
          %Tesla.Env{status: 404, body: ""}
      end)

      assert Utils.maybe_notify_mentioned_recipients(["test-test"], activity) == [
               "test-test"
             ]
    end
  end

  describe "attachments_from_ids_descs/2" do
    test "returns [] when attachment ids is empty" do
      assert Utils.attachments_from_ids_descs([], "{}") == []
    end

    test "returns list attachments with desc" do
      object = insert(:note)
      desc = Jason.encode!(%{object.id => "test-desc"})

      assert Utils.attachments_from_ids_descs(["#{object.id}", "34"], desc) == [
               Map.merge(object.data, %{"name" => "test-desc"})
             ]
    end
  end

  describe "attachments_from_ids/1" do
    test "returns attachments with descs" do
      object = insert(:note)
      desc = Jason.encode!(%{object.id => "test-desc"})

      assert Utils.attachments_from_ids(%{
               media_ids: ["#{object.id}"],
               descriptions: desc
             }) == [
               Map.merge(object.data, %{"name" => "test-desc"})
             ]
    end

    test "returns attachments without descs" do
      object = insert(:note)
      assert Utils.attachments_from_ids(%{media_ids: ["#{object.id}"]}) == [object.data]
    end

    test "returns [] when not pass media_ids" do
      assert Utils.attachments_from_ids(%{}) == []
    end
  end

  describe "maybe_add_list_data/3" do
    test "adds list params when found user list" do
      user = insert(:user)
      {:ok, %Pleroma.List{} = list} = Pleroma.List.create("title", user)

      assert Utils.maybe_add_list_data(%{additional: %{}, object: %{}}, user, {:list, list.id}) ==
               %{
                 additional: %{"bcc" => [list.ap_id], "listMessage" => list.ap_id},
                 object: %{"listMessage" => list.ap_id}
               }
    end

    test "returns original params when list not found" do
      user = insert(:user)
      {:ok, %Pleroma.List{} = list} = Pleroma.List.create("title", insert(:user))

      assert Utils.maybe_add_list_data(%{additional: %{}, object: %{}}, user, {:list, list.id}) ==
               %{additional: %{}, object: %{}}
    end
  end

  describe "make_note_data/11" do
    test "returns note data" do
      user = insert(:user)
      note = insert(:note)
      user2 = insert(:user)
      user3 = insert(:user)

      assert Utils.make_note_data(
               user.ap_id,
               [user2.ap_id],
               "2hu",
               "<h1>This is :moominmamma: note</h1>",
               [],
               note.id,
               [name: "jimm"],
               "test summary",
               [user3.ap_id],
               false,
               %{"custom_tag" => "test"}
             ) == %{
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
               "custom_tag" => "test"
             }
    end
  end

  describe "maybe_add_attachments/3" do
    test "returns parsed results when attachment_links is false" do
      assert Utils.maybe_add_attachments(
               {"test", [], ["tags"]},
               [],
               false
             ) == {"test", [], ["tags"]}
    end

    test "adds attachments to parsed results" do
      attachment = %{"url" => [%{"href" => "SakuraPM.png"}]}

      assert Utils.maybe_add_attachments(
               {"test", [], ["tags"]},
               [attachment],
               true
             ) == {
               "test<br><a href=\"SakuraPM.png\" class='attachment'>SakuraPM.png</a>",
               [],
               ["tags"]
             }
    end
  end
end
