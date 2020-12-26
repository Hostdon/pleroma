# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.TimelineControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import Tesla.Mock

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "home" do
    setup do: oauth_access(["read:statuses"])

    test "does NOT embed account/pleroma/relationship in statuses", %{
      user: user,
      conn: conn
    } do
      other_user = insert(:user)

      {:ok, _} = CommonAPI.post(other_user, %{status: "hi @#{user.nickname}"})

      response =
        conn
        |> assign(:user, user)
        |> get("/api/v1/timelines/home")
        |> json_response_and_validate_schema(200)

      assert Enum.all?(response, fn n ->
               get_in(n, ["account", "pleroma", "relationship"]) == %{}
             end)
    end

    test "the home timeline when the direct messages are excluded", %{user: user, conn: conn} do
      {:ok, public_activity} = CommonAPI.post(user, %{status: ".", visibility: "public"})
      {:ok, direct_activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})

      {:ok, unlisted_activity} = CommonAPI.post(user, %{status: ".", visibility: "unlisted"})

      {:ok, private_activity} = CommonAPI.post(user, %{status: ".", visibility: "private"})

      conn = get(conn, "/api/v1/timelines/home?exclude_visibilities[]=direct")

      assert status_ids = json_response_and_validate_schema(conn, :ok) |> Enum.map(& &1["id"])
      assert public_activity.id in status_ids
      assert unlisted_activity.id in status_ids
      assert private_activity.id in status_ids
      refute direct_activity.id in status_ids
    end
  end

  describe "public" do
    @tag capture_log: true
    test "the public timeline", %{conn: conn} do
      user = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "test"})

      _activity = insert(:note_activity, local: false)

      conn = get(conn, "/api/v1/timelines/public?local=False")

      assert length(json_response_and_validate_schema(conn, :ok)) == 2

      conn = get(build_conn(), "/api/v1/timelines/public?local=True")

      assert [%{"content" => "test"}] = json_response_and_validate_schema(conn, :ok)

      conn = get(build_conn(), "/api/v1/timelines/public?local=1")

      assert [%{"content" => "test"}] = json_response_and_validate_schema(conn, :ok)

      # does not contain repeats
      {:ok, _} = CommonAPI.repeat(activity.id, user)

      conn = get(build_conn(), "/api/v1/timelines/public?local=true")

      assert [_] = json_response_and_validate_schema(conn, :ok)
    end

    test "the public timeline includes only public statuses for an authenticated user" do
      %{user: user, conn: conn} = oauth_access(["read:statuses"])

      {:ok, _activity} = CommonAPI.post(user, %{status: "test"})
      {:ok, _activity} = CommonAPI.post(user, %{status: "test", visibility: "private"})
      {:ok, _activity} = CommonAPI.post(user, %{status: "test", visibility: "unlisted"})
      {:ok, _activity} = CommonAPI.post(user, %{status: "test", visibility: "direct"})

      res_conn = get(conn, "/api/v1/timelines/public")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 1
    end

    test "doesn't return replies if follower is posting with blocked user" do
      %{conn: conn, user: blocker} = oauth_access(["read:statuses"])
      [blockee, friend] = insert_list(2, :user)
      {:ok, blocker} = User.follow(blocker, friend)
      {:ok, _} = User.block(blocker, blockee)

      conn = assign(conn, :user, blocker)

      {:ok, %{id: activity_id} = activity} = CommonAPI.post(friend, %{status: "hey!"})

      {:ok, reply_from_blockee} =
        CommonAPI.post(blockee, %{status: "heya", in_reply_to_status_id: activity})

      {:ok, _reply_from_friend} =
        CommonAPI.post(friend, %{status: "status", in_reply_to_status_id: reply_from_blockee})

      # Still shows replies from yourself
      {:ok, %{id: reply_from_me}} =
        CommonAPI.post(blocker, %{status: "status", in_reply_to_status_id: reply_from_blockee})

      response =
        get(conn, "/api/v1/timelines/public")
        |> json_response_and_validate_schema(200)

      assert length(response) == 2
      [%{"id" => ^reply_from_me}, %{"id" => ^activity_id}] = response
    end

    test "doesn't return replies if follow is posting with users from blocked domain" do
      %{conn: conn, user: blocker} = oauth_access(["read:statuses"])
      friend = insert(:user)
      blockee = insert(:user, ap_id: "https://example.com/users/blocked")
      {:ok, blocker} = User.follow(blocker, friend)
      {:ok, blocker} = User.block_domain(blocker, "example.com")

      conn = assign(conn, :user, blocker)

      {:ok, %{id: activity_id} = activity} = CommonAPI.post(friend, %{status: "hey!"})

      {:ok, reply_from_blockee} =
        CommonAPI.post(blockee, %{status: "heya", in_reply_to_status_id: activity})

      {:ok, _reply_from_friend} =
        CommonAPI.post(friend, %{status: "status", in_reply_to_status_id: reply_from_blockee})

      res_conn = get(conn, "/api/v1/timelines/public")

      activities = json_response_and_validate_schema(res_conn, 200)
      [%{"id" => ^activity_id}] = activities
    end
  end

  defp local_and_remote_activities do
    insert(:note_activity)
    insert(:note_activity, local: false)
    :ok
  end

  describe "public with restrict unauthenticated timeline for local and federated timelines" do
    setup do: local_and_remote_activities()

    setup do: clear_config([:restrict_unauthenticated, :timelines, :local], true)

    setup do: clear_config([:restrict_unauthenticated, :timelines, :federated], true)

    test "if user is unauthenticated", %{conn: conn} do
      res_conn = get(conn, "/api/v1/timelines/public?local=true")

      assert json_response_and_validate_schema(res_conn, :unauthorized) == %{
               "error" => "authorization required for timeline view"
             }

      res_conn = get(conn, "/api/v1/timelines/public?local=false")

      assert json_response_and_validate_schema(res_conn, :unauthorized) == %{
               "error" => "authorization required for timeline view"
             }
    end

    test "if user is authenticated" do
      %{conn: conn} = oauth_access(["read:statuses"])

      res_conn = get(conn, "/api/v1/timelines/public?local=true")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 1

      res_conn = get(conn, "/api/v1/timelines/public?local=false")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 2
    end
  end

  describe "public with restrict unauthenticated timeline for local" do
    setup do: local_and_remote_activities()

    setup do: clear_config([:restrict_unauthenticated, :timelines, :local], true)

    test "if user is unauthenticated", %{conn: conn} do
      res_conn = get(conn, "/api/v1/timelines/public?local=true")

      assert json_response_and_validate_schema(res_conn, :unauthorized) == %{
               "error" => "authorization required for timeline view"
             }

      res_conn = get(conn, "/api/v1/timelines/public?local=false")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 2
    end

    test "if user is authenticated", %{conn: _conn} do
      %{conn: conn} = oauth_access(["read:statuses"])

      res_conn = get(conn, "/api/v1/timelines/public?local=true")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 1

      res_conn = get(conn, "/api/v1/timelines/public?local=false")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 2
    end
  end

  describe "public with restrict unauthenticated timeline for remote" do
    setup do: local_and_remote_activities()

    setup do: clear_config([:restrict_unauthenticated, :timelines, :federated], true)

    test "if user is unauthenticated", %{conn: conn} do
      res_conn = get(conn, "/api/v1/timelines/public?local=true")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 1

      res_conn = get(conn, "/api/v1/timelines/public?local=false")

      assert json_response_and_validate_schema(res_conn, :unauthorized) == %{
               "error" => "authorization required for timeline view"
             }
    end

    test "if user is authenticated", %{conn: _conn} do
      %{conn: conn} = oauth_access(["read:statuses"])

      res_conn = get(conn, "/api/v1/timelines/public?local=true")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 1

      res_conn = get(conn, "/api/v1/timelines/public?local=false")
      assert length(json_response_and_validate_schema(res_conn, 200)) == 2
    end
  end

  describe "direct" do
    test "direct timeline", %{conn: conn} do
      user_one = insert(:user)
      user_two = insert(:user)

      {:ok, user_two} = User.follow(user_two, user_one)

      {:ok, direct} =
        CommonAPI.post(user_one, %{
          status: "Hi @#{user_two.nickname}!",
          visibility: "direct"
        })

      {:ok, _follower_only} =
        CommonAPI.post(user_one, %{
          status: "Hi @#{user_two.nickname}!",
          visibility: "private"
        })

      conn_user_two =
        conn
        |> assign(:user, user_two)
        |> assign(:token, insert(:oauth_token, user: user_two, scopes: ["read:statuses"]))

      # Only direct should be visible here
      res_conn = get(conn_user_two, "api/v1/timelines/direct")

      assert [status] = json_response_and_validate_schema(res_conn, :ok)

      assert %{"visibility" => "direct"} = status
      assert status["url"] != direct.data["id"]

      # User should be able to see their own direct message
      res_conn =
        build_conn()
        |> assign(:user, user_one)
        |> assign(:token, insert(:oauth_token, user: user_one, scopes: ["read:statuses"]))
        |> get("api/v1/timelines/direct")

      [status] = json_response_and_validate_schema(res_conn, :ok)

      assert %{"visibility" => "direct"} = status

      # Both should be visible here
      res_conn = get(conn_user_two, "api/v1/timelines/home")

      [_s1, _s2] = json_response_and_validate_schema(res_conn, :ok)

      # Test pagination
      Enum.each(1..20, fn _ ->
        {:ok, _} =
          CommonAPI.post(user_one, %{
            status: "Hi @#{user_two.nickname}!",
            visibility: "direct"
          })
      end)

      res_conn = get(conn_user_two, "api/v1/timelines/direct")

      statuses = json_response_and_validate_schema(res_conn, :ok)
      assert length(statuses) == 20

      max_id = List.last(statuses)["id"]

      res_conn = get(conn_user_two, "api/v1/timelines/direct?max_id=#{max_id}")

      assert [status] = json_response_and_validate_schema(res_conn, :ok)

      assert status["url"] != direct.data["id"]
    end

    test "doesn't include DMs from blocked users" do
      %{user: blocker, conn: conn} = oauth_access(["read:statuses"])
      blocked = insert(:user)
      other_user = insert(:user)
      {:ok, _user_relationship} = User.block(blocker, blocked)

      {:ok, _blocked_direct} =
        CommonAPI.post(blocked, %{
          status: "Hi @#{blocker.nickname}!",
          visibility: "direct"
        })

      {:ok, direct} =
        CommonAPI.post(other_user, %{
          status: "Hi @#{blocker.nickname}!",
          visibility: "direct"
        })

      res_conn = get(conn, "api/v1/timelines/direct")

      [status] = json_response_and_validate_schema(res_conn, :ok)
      assert status["id"] == direct.id
    end
  end

  describe "list" do
    setup do: oauth_access(["read:lists"])

    test "does not contain retoots", %{user: user, conn: conn} do
      other_user = insert(:user)
      {:ok, activity_one} = CommonAPI.post(user, %{status: "Marisa is cute."})
      {:ok, activity_two} = CommonAPI.post(other_user, %{status: "Marisa is stupid."})
      {:ok, _} = CommonAPI.repeat(activity_one.id, other_user)

      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn = get(conn, "/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response_and_validate_schema(conn, :ok)

      assert id == to_string(activity_two.id)
    end

    test "works with pagination", %{user: user, conn: conn} do
      other_user = insert(:user)
      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      Enum.each(1..30, fn i ->
        CommonAPI.post(other_user, %{status: "post number #{i}"})
      end)

      res =
        get(conn, "/api/v1/timelines/list/#{list.id}?limit=1")
        |> json_response_and_validate_schema(:ok)

      assert length(res) == 1

      [first] = res

      res =
        get(conn, "/api/v1/timelines/list/#{list.id}?max_id=#{first["id"]}&limit=30")
        |> json_response_and_validate_schema(:ok)

      assert length(res) == 29
    end

    test "list timeline", %{user: user, conn: conn} do
      other_user = insert(:user)
      {:ok, _activity_one} = CommonAPI.post(user, %{status: "Marisa is cute."})
      {:ok, activity_two} = CommonAPI.post(other_user, %{status: "Marisa is cute."})
      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn = get(conn, "/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response_and_validate_schema(conn, :ok)

      assert id == to_string(activity_two.id)
    end

    test "list timeline does not leak non-public statuses for unfollowed users", %{
      user: user,
      conn: conn
    } do
      other_user = insert(:user)
      {:ok, activity_one} = CommonAPI.post(other_user, %{status: "Marisa is cute."})

      {:ok, _activity_two} =
        CommonAPI.post(other_user, %{
          status: "Marisa is cute.",
          visibility: "private"
        })

      {:ok, list} = Pleroma.List.create("name", user)
      {:ok, list} = Pleroma.List.follow(list, other_user)

      conn = get(conn, "/api/v1/timelines/list/#{list.id}")

      assert [%{"id" => id}] = json_response_and_validate_schema(conn, :ok)

      assert id == to_string(activity_one.id)
    end
  end

  describe "hashtag" do
    setup do: oauth_access(["n/a"])

    @tag capture_log: true
    test "hashtag timeline", %{conn: conn} do
      following = insert(:user)

      {:ok, activity} = CommonAPI.post(following, %{status: "test #2hu"})

      nconn = get(conn, "/api/v1/timelines/tag/2hu")

      assert [%{"id" => id}] = json_response_and_validate_schema(nconn, :ok)

      assert id == to_string(activity.id)

      # works for different capitalization too
      nconn = get(conn, "/api/v1/timelines/tag/2HU")

      assert [%{"id" => id}] = json_response_and_validate_schema(nconn, :ok)

      assert id == to_string(activity.id)
    end

    test "multi-hashtag timeline", %{conn: conn} do
      user = insert(:user)

      {:ok, activity_test} = CommonAPI.post(user, %{status: "#test"})
      {:ok, activity_test1} = CommonAPI.post(user, %{status: "#test #test1"})
      {:ok, activity_none} = CommonAPI.post(user, %{status: "#test #none"})

      any_test = get(conn, "/api/v1/timelines/tag/test?any[]=test1")

      [status_none, status_test1, status_test] = json_response_and_validate_schema(any_test, :ok)

      assert to_string(activity_test.id) == status_test["id"]
      assert to_string(activity_test1.id) == status_test1["id"]
      assert to_string(activity_none.id) == status_none["id"]

      restricted_test = get(conn, "/api/v1/timelines/tag/test?all[]=test1&none[]=none")

      assert [status_test1] == json_response_and_validate_schema(restricted_test, :ok)

      all_test = get(conn, "/api/v1/timelines/tag/test?all[]=none")

      assert [status_none] == json_response_and_validate_schema(all_test, :ok)
    end
  end

  describe "hashtag timeline handling of :restrict_unauthenticated setting" do
    setup do
      user = insert(:user)
      {:ok, activity1} = CommonAPI.post(user, %{status: "test #tag1"})
      {:ok, _activity2} = CommonAPI.post(user, %{status: "test #tag1"})

      activity1
      |> Ecto.Changeset.change(%{local: false})
      |> Pleroma.Repo.update()

      base_uri = "/api/v1/timelines/tag/tag1"
      error_response = %{"error" => "authorization required for timeline view"}

      %{base_uri: base_uri, error_response: error_response}
    end

    defp ensure_authenticated_access(base_uri) do
      %{conn: auth_conn} = oauth_access(["read:statuses"])

      res_conn = get(auth_conn, "#{base_uri}?local=true")
      assert length(json_response(res_conn, 200)) == 1

      res_conn = get(auth_conn, "#{base_uri}?local=false")
      assert length(json_response(res_conn, 200)) == 2
    end

    test "with default settings on private instances, returns 403 for unauthenticated users", %{
      conn: conn,
      base_uri: base_uri,
      error_response: error_response
    } do
      clear_config([:instance, :public], false)
      clear_config([:restrict_unauthenticated, :timelines])

      for local <- [true, false] do
        res_conn = get(conn, "#{base_uri}?local=#{local}")

        assert json_response(res_conn, :unauthorized) == error_response
      end

      ensure_authenticated_access(base_uri)
    end

    test "with `%{local: true, federated: true}`, returns 403 for unauthenticated users", %{
      conn: conn,
      base_uri: base_uri,
      error_response: error_response
    } do
      clear_config([:restrict_unauthenticated, :timelines, :local], true)
      clear_config([:restrict_unauthenticated, :timelines, :federated], true)

      for local <- [true, false] do
        res_conn = get(conn, "#{base_uri}?local=#{local}")

        assert json_response(res_conn, :unauthorized) == error_response
      end

      ensure_authenticated_access(base_uri)
    end

    test "with `%{local: false, federated: true}`, forbids unauthenticated access to federated timeline",
         %{conn: conn, base_uri: base_uri, error_response: error_response} do
      clear_config([:restrict_unauthenticated, :timelines, :local], false)
      clear_config([:restrict_unauthenticated, :timelines, :federated], true)

      res_conn = get(conn, "#{base_uri}?local=true")
      assert length(json_response(res_conn, 200)) == 1

      res_conn = get(conn, "#{base_uri}?local=false")
      assert json_response(res_conn, :unauthorized) == error_response

      ensure_authenticated_access(base_uri)
    end

    test "with `%{local: true, federated: false}`, forbids unauthenticated access to public timeline" <>
           "(but not to local public activities which are delivered as part of federated timeline)",
         %{conn: conn, base_uri: base_uri, error_response: error_response} do
      clear_config([:restrict_unauthenticated, :timelines, :local], true)
      clear_config([:restrict_unauthenticated, :timelines, :federated], false)

      res_conn = get(conn, "#{base_uri}?local=true")
      assert json_response(res_conn, :unauthorized) == error_response

      # Note: local activities get delivered as part of federated timeline
      res_conn = get(conn, "#{base_uri}?local=false")
      assert length(json_response(res_conn, 200)) == 2

      ensure_authenticated_access(base_uri)
    end
  end
end
