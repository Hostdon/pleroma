# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.DatabaseSearchTest do
  alias Pleroma.Activity
  alias Pleroma.Search.DatabaseSearch
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Tests.ObanHelpers
  import Pleroma.Factory

  use Pleroma.DataCase, async: false

  test "it finds something" do
    user = insert(:user)
    {:ok, post} = CommonAPI.post(user, %{status: "it's wednesday my dudes"})

    [result] = DatabaseSearch.search(nil, "wednesday")

    assert result.id == post.id
  end

  test "doesn’t explode with gin fuzzy limit set" do
    clear_config([Pleroma.Search.DatabaseSearch, :gin_fuzzy_search_limit], 10_000)

    user = insert(:user)
    {:ok, post} = CommonAPI.post(user, %{status: "it's wednesday my dudes"})

    [result] = DatabaseSearch.search(nil, "wednesday")

    assert result.id == post.id
  end

  test "using websearch_to_tsquery" do
    user = insert(:user)
    {:ok, _post} = CommonAPI.post(user, %{status: "it's wednesday my dudes"})
    {:ok, other_post} = CommonAPI.post(user, %{status: "it's wednesday my bros"})

    assert [result] = DatabaseSearch.search(nil, "wednesday -dudes")

    assert result.id == other_post.id
  end

  describe "search post content" do
    setup do
      Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)

      user = insert(:user)

      params = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => "http://mastodon.example.org/users/admin",
        "type" => "Create",
        "id" => "http://mastodon.example.org/users/admin/activities/1",
        "object" => %{
          "type" => "Note",
          "content" => "find me!",
          "id" => "http://mastodon.example.org/users/admin/objects/1",
          "attributedTo" => "http://mastodon.example.org/users/admin",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      {:ok, local_activity} = Pleroma.Web.CommonAPI.post(user, %{status: "find me!"})
      {:ok, japanese_activity} = Pleroma.Web.CommonAPI.post(user, %{status: "更新情報"})
      {:ok, job} = Pleroma.Web.Federator.incoming_ap_doc(params)
      {:ok, remote_activity} = ObanHelpers.perform(job)
      remote_activity = Activity.get_by_id_with_object(remote_activity.id)

      %{
        japanese_activity: japanese_activity,
        local_activity: local_activity,
        remote_activity: remote_activity,
        user: user
      }
    end

    setup do: clear_config([:instance, :limit_to_local_content])

    test "finds utf8 text in statuses", %{
      japanese_activity: japanese_activity,
      user: user
    } do
      activities = DatabaseSearch.search(user, "更新情報")

      assert [^japanese_activity] = activities
    end

    test "finds post via content warning", %{user: user} do
      {:ok, activity} =
        Pleroma.Web.CommonAPI.post(user, %{
          status: "bug friend",
          spoiler_text: "closeup of very large bug"
        })

      activities = DatabaseSearch.search(user, "\"very large bug\"")

      assert [^activity] = activities
    end

    test "find local and remote statuses for authenticated users", %{
      local_activity: local_activity,
      remote_activity: remote_activity,
      user: user
    } do
      activities = Enum.sort_by(DatabaseSearch.search(user, "find me"), & &1.id)

      assert [^local_activity, ^remote_activity] = activities
    end

    test "find only local statuses for unauthenticated users", %{local_activity: local_activity} do
      assert [^local_activity] = DatabaseSearch.search(nil, "find me")
    end

    test "find only local statuses for unauthenticated users  when `limit_to_local_content` is `:all`",
         %{local_activity: local_activity} do
      clear_config([:instance, :limit_to_local_content], :all)
      assert [^local_activity] = DatabaseSearch.search(nil, "find me")
    end

    test "find all statuses for unauthenticated users when `limit_to_local_content` is `false`",
         %{
           local_activity: local_activity,
           remote_activity: remote_activity
         } do
      clear_config([:instance, :limit_to_local_content], false)

      activities = Enum.sort_by(DatabaseSearch.search(nil, "find me"), & &1.id)

      assert [^local_activity, ^remote_activity] = activities
    end
  end
end
