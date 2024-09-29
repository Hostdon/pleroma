# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StaticFE.StaticFEControllerTest do
  use Pleroma.Web.ConnCase, async: false

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup_all do: clear_config([:static_fe, :enabled], true)
  setup do: clear_config([Pleroma.Upload, :uploader], Pleroma.Uploaders.Local)

  setup %{conn: conn} do
    conn = put_req_header(conn, "accept", "text/html")

    user_avatar_url = "https://example.org/akko.png"

    user =
      insert(:user,
        local: true,
        name: "Akko",
        nickname: "atsuko",
        bio: "A believing heart is my magic!",
        raw_bio: "A believing heart is my magic!",
        avatar: %{
          "url" => [
            %{
              "href" => user_avatar_url
            }
          ]
        }
      )

    %{conn: conn, user: user, user_avatar_url: user_avatar_url}
  end

  describe "user profile html" do
    test "just the profile as HTML", %{conn: conn, user: user} do
      conn = get(conn, "/users/#{user.nickname}")

      assert html_response(conn, 200) =~ user.nickname
    end

    test "404 when user not found", %{conn: conn} do
      conn = get(conn, "/users/limpopo")

      assert html_response(conn, 404) =~ "not found"
    end

    test "profile does not include private messages", %{conn: conn, user: user} do
      CommonAPI.post(user, %{status: "public"})
      CommonAPI.post(user, %{status: "private", visibility: "private"})

      conn = get(conn, "/users/#{user.nickname}")

      html = html_response(conn, 200)

      assert html =~ "\npublic\n"
      refute html =~ "\nprivate\n"
    end

    test "main page does not include replies", %{conn: conn, user: user} do
      {:ok, op} = CommonAPI.post(user, %{status: "beep"})
      CommonAPI.post(user, %{status: "boop", in_reply_to_id: op})

      conn = get(conn, "/users/#{user.nickname}")

      html = html_response(conn, 200)

      assert html =~ "\nbeep\n"
      refute html =~ "\nboop\n"
    end

    test "media page only includes posts with attachments", %{conn: conn, user: user} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %{id: media_id}} = ActivityPub.upload(file, actor: user.ap_id)

      CommonAPI.post(user, %{status: "virgin text post"})
      CommonAPI.post(user, %{status: "chad post with attachment", media_ids: [media_id]})

      conn = get(conn, "/users/#{user.nickname}/media")

      html = html_response(conn, 200)

      assert html =~ "\nchad post with attachment\n"
      refute html =~ "\nvirgin text post\n"
    end

    test "show follower list", %{conn: conn, user: user} do
      follower = insert(:user)
      CommonAPI.follow(follower, user)

      conn = get(conn, "/users/#{user.nickname}/followers")

      html = html_response(conn, 200)

      assert html =~ "user-card"
    end

    test "don't show followers if hidden", %{conn: conn, user: user} do
      follower = insert(:user)
      CommonAPI.follow(follower, user)

      {:ok, user} =
        user
        |> User.update_changeset(%{hide_followers: true})
        |> User.update_and_set_cache()

      conn = get(conn, "/users/#{user.nickname}/followers")

      html = html_response(conn, 200)

      refute html =~ "user-card"
    end

    test "pagination", %{conn: conn, user: user} do
      Enum.map(1..30, fn i -> CommonAPI.post(user, %{status: "test#{i}"}) end)

      conn = get(conn, "/users/#{user.nickname}")

      html = html_response(conn, 200)

      assert html =~ "\ntest30\n"
      assert html =~ "\ntest11\n"
      refute html =~ "\ntest10\n"
      refute html =~ "\ntest1\n"
    end

    test "pagination, page 2", %{conn: conn, user: user} do
      activities = Enum.map(1..30, fn i -> CommonAPI.post(user, %{status: "test#{i}"}) end)
      {:ok, a11} = Enum.at(activities, 11)

      conn = get(conn, "/users/#{user.nickname}?max_id=#{a11.id}")

      html = html_response(conn, 200)

      assert html =~ "\ntest1\n"
      assert html =~ "\ntest10\n"
      refute html =~ "\ntest20\n"
      refute html =~ "\ntest29\n"
    end

    test "does not require authentication on non-federating instances", %{
      conn: conn,
      user: user
    } do
      clear_config([:instance, :federating], false)

      conn = get(conn, "/users/#{user.nickname}")

      assert html_response(conn, 200) =~ user.nickname
    end

    test "returns 404 for local user with `restrict_unauthenticated/profiles/local` setting", %{
      conn: conn
    } do
      clear_config([:restrict_unauthenticated, :profiles, :local], true)

      local_user = insert(:user, local: true)

      conn
      |> get("/users/#{local_user.nickname}")
      |> html_response(404)
    end
  end

  describe "notice html" do
    test "single notice page", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "testing a thing!"})

      conn = get(conn, "/notice/#{activity.id}")

      html = html_response(conn, 200)
      assert html =~ "<div class=\"panel conversation\">"
      assert html =~ user.nickname
      assert html =~ "testing a thing!"
    end

    test "redirects to json if requested", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "testing a thing!"})

      conn =
        conn
        |> put_req_header(
          "accept",
          "Accept: application/activity+json, application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\", text/html"
        )
        |> get("/notice/#{activity.id}")

      assert redirected_to(conn, 302) =~ activity.data["object"]
    end

    test "filters HTML tags", %{conn: conn} do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "<script>alert('xss')</script>"})

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/notice/#{activity.id}")

      html = html_response(conn, 200)
      assert html =~ ~s[&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;]
    end

    test "shows the whole thread", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "space: the final frontier"})

      CommonAPI.post(user, %{
        status: "these are the voyages or something",
        in_reply_to_status_id: activity.id
      })

      conn = get(conn, "/notice/#{activity.id}")

      html = html_response(conn, 200)
      assert html =~ "the final frontier"
      assert html =~ "voyages"
    end

    test "redirect by AP object ID", %{conn: conn, user: user} do
      {:ok, %Activity{data: %{"object" => object_url}}} =
        CommonAPI.post(user, %{status: "beam me up"})

      conn = get(conn, URI.parse(object_url).path)

      assert html_response(conn, 302) =~ "redirected"
    end

    test "redirect by activity ID", %{conn: conn, user: user} do
      {:ok, %Activity{data: %{"id" => id}}} =
        CommonAPI.post(user, %{status: "I'm a doctor, not a devops!"})

      conn = get(conn, URI.parse(id).path)

      assert html_response(conn, 302) =~ "redirected"
    end

    test "404 when notice not found", %{conn: conn} do
      conn = get(conn, "/notice/88c9c317")

      assert html_response(conn, 404) =~ "not found"
    end

    test "404 for private status", %{conn: conn, user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "don't show me!", visibility: "private"})

      conn = get(conn, "/notice/#{activity.id}")

      assert html_response(conn, 404) =~ "not found"
    end

    test "302 for remote cached status", %{conn: conn, user: user} do
      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Create",
        "actor" => user.ap_id,
        "object" => %{
          "to" => user.follower_address,
          "cc" => "https://www.w3.org/ns/activitystreams#Public",
          "id" => Utils.generate_object_id(),
          "content" => "blah blah blah",
          "type" => "Note",
          "attributedTo" => user.ap_id
        }
      }

      assert {:ok, activity} = Transmogrifier.handle_incoming(message)

      conn = get(conn, "/notice/#{activity.id}")

      assert html_response(conn, 302) =~ "redirected"
    end

    test "does not require authentication on non-federating instances", %{
      conn: conn,
      user: user
    } do
      clear_config([:instance, :federating], false)

      {:ok, activity} = CommonAPI.post(user, %{status: "testing a thing!"})

      conn = get(conn, "/notice/#{activity.id}")

      assert html_response(conn, 200) =~ "testing a thing!"
    end

    test "returns 404 for local public activity with `restrict_unauthenticated/activities/local` setting",
         %{conn: conn, user: user} do
      clear_config([:restrict_unauthenticated, :activities, :local], true)

      {:ok, activity} = CommonAPI.post(user, %{status: "testing a thing!"})

      conn
      |> get("/notice/#{activity.id}")
      |> html_response(404)
    end
  end

  defp meta_content(metadata_tag) do
    :proplists.get_value("content", metadata_tag)
  end

  defp meta_find_og(document, name) do
    Floki.find(document, "head>meta[property=\"og:" <> name <> "\"]")
  end

  defp meta_find_twitter(document, name) do
    Floki.find(document, "head>meta[name=\"twitter:" <> name <> "\"]")
  end

  # Detailed metadata tests are already done for each builder individually, so just
  # one check per type of content should suffice to ensure we're calling the providers correctly
  describe "metadata tags for" do
    setup do
      clear_config([Pleroma.Web.Metadata, :providers], [
        Pleroma.Web.Metadata.Providers.OpenGraph,
        Pleroma.Web.Metadata.Providers.TwitterCard
      ])
    end

    test "user profile", %{conn: conn, user: user, user_avatar_url: user_avatar_url} do
      conn = get(conn, "/users/#{user.nickname}")
      html = html_response(conn, 200)

      {:ok, document} = Floki.parse_document(html)

      [{"meta", og_type, _}] = meta_find_og(document, "type")
      [{"meta", og_title, _}] = meta_find_og(document, "title")
      [{"meta", og_url, _}] = meta_find_og(document, "url")
      [{"meta", og_desc, _}] = meta_find_og(document, "description")
      [{"meta", og_img, _}] = meta_find_og(document, "image")
      [{"meta", og_imgw, _}] = meta_find_og(document, "image:width")
      [{"meta", og_imgh, _}] = meta_find_og(document, "image:height")

      [{"meta", tw_card, _}] = meta_find_twitter(document, "card")
      [{"meta", tw_title, _}] = meta_find_twitter(document, "title")
      [{"meta", tw_desc, _}] = meta_find_twitter(document, "description")
      [{"meta", tw_img, _}] = meta_find_twitter(document, "image")

      assert meta_content(og_type) == "article"
      assert meta_content(og_title) == Pleroma.Web.Metadata.Utils.user_name_string(user)
      assert meta_content(og_url) == user.ap_id
      assert meta_content(og_desc) == user.bio
      assert meta_content(og_img) == user_avatar_url
      assert meta_content(og_imgw) == "150"
      assert meta_content(og_imgh) == "150"

      assert meta_content(tw_card) == "summary"
      assert meta_content(tw_title) == meta_content(og_title)
      assert meta_content(tw_desc) == meta_content(og_desc)
      assert meta_content(tw_img) == meta_content(og_img)
    end

    test "text-only post", %{conn: conn, user: user, user_avatar_url: user_avatar_url} do
      post_text = "How are lessons about magic  t h i s  boring?!"
      {:ok, activity} = CommonAPI.post(user, %{status: post_text})

      conn = get(conn, "/notice/#{activity.id}")
      html = html_response(conn, 200)

      {:ok, document} = Floki.parse_document(html)

      [{"meta", og_type, _}] = meta_find_og(document, "type")
      [{"meta", og_title, _}] = meta_find_og(document, "title")
      [{"meta", og_url, _}] = meta_find_og(document, "url")
      [{"meta", og_desc, _}] = meta_find_og(document, "description")
      [{"meta", og_img, _}] = meta_find_og(document, "image")
      [{"meta", og_imgw, _}] = meta_find_og(document, "image:width")
      [{"meta", og_imgh, _}] = meta_find_og(document, "image:height")

      [{"meta", tw_card, _}] = meta_find_twitter(document, "card")
      [{"meta", tw_title, _}] = meta_find_twitter(document, "title")
      [{"meta", tw_desc, _}] = meta_find_twitter(document, "description")
      [{"meta", tw_img, _}] = meta_find_twitter(document, "image")

      assert meta_content(og_type) == "article"
      assert meta_content(og_title) == Pleroma.Web.Metadata.Utils.user_name_string(user)
      assert meta_content(og_url) == activity.data["id"]
      assert meta_content(og_desc) == post_text
      assert meta_content(og_img) == user_avatar_url
      assert meta_content(og_imgw) == "150"
      assert meta_content(og_imgh) == "150"

      assert meta_content(tw_card) == "summary"
      assert meta_content(tw_title) == meta_content(og_title)
      assert meta_content(tw_desc) == meta_content(og_desc)
      assert meta_content(tw_img) == meta_content(og_img)
    end

    test "post with attachments", %{conn: conn, user: user} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      alt_text = "The rarest of all Shiny Chariot cards"
      {:ok, upload_data} = ActivityPub.upload(file, actor: user.ap_id, description: alt_text)

      %{id: media_id, data: %{"url" => [%{"href" => media_url}]}} = upload_data

      post_text = "Look!"
      {:ok, activity} = CommonAPI.post(user, %{status: post_text, media_ids: [media_id]})

      conn = get(conn, "/notice/#{activity.id}")
      html = html_response(conn, 200)

      {:ok, document} = Floki.parse_document(html)

      [{"meta", og_type, _}] = meta_find_og(document, "type")
      [{"meta", og_title, _}] = meta_find_og(document, "title")
      [{"meta", og_url, _}] = meta_find_og(document, "url")
      [{"meta", og_desc, _}] = meta_find_og(document, "description")
      [{"meta", og_img, _}] = meta_find_og(document, "image")
      [{"meta", og_alt, _}] = meta_find_og(document, "image:alt")

      [{"meta", tw_card, _}] = meta_find_twitter(document, "card")
      [{"meta", tw_title, _}] = meta_find_twitter(document, "title")
      [{"meta", tw_desc, _}] = meta_find_twitter(document, "description")
      [{"meta", tw_player, _}] = meta_find_twitter(document, "player")

      assert meta_content(og_type) == "article"
      assert meta_content(og_title) == Pleroma.Web.Metadata.Utils.user_name_string(user)
      assert meta_content(og_url) == activity.data["id"]
      assert meta_content(og_desc) == post_text
      assert meta_content(og_img) == media_url
      assert meta_content(og_alt) == alt_text

      # Audio and video attachments use "player" and have some more metadata
      assert meta_content(tw_card) == "summary_large_image"
      assert meta_content(tw_title) == meta_content(og_title)
      assert meta_content(tw_desc) == meta_content(og_desc)
      assert meta_content(tw_player) == meta_content(og_img)
    end
  end
end
