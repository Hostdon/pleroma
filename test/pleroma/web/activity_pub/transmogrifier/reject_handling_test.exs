# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.RejectHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it fails for incoming rejects which cannot be correlated" do
    follower = insert(:user)
    followed = insert(:user, is_locked: true)

    accept_data =
      File.read!("test/fixtures/mastodon-reject-activity.json")
      |> Jason.decode!()
      |> Map.put("actor", followed.ap_id)

    accept_data =
      Map.put(accept_data, "object", Map.put(accept_data["object"], "actor", follower.ap_id))

    {:error, _} = Transmogrifier.handle_incoming(accept_data)

    follower = User.get_cached_by_id(follower.id)

    refute User.following?(follower, followed) == true
  end

  test "it works for incoming rejects which are referenced by IRI only" do
    follower = insert(:user)
    followed = insert(:user, is_locked: true)

    {:ok, follower, followed} = User.follow(follower, followed)
    {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)

    assert User.following?(follower, followed) == true

    reject_data =
      File.read!("test/fixtures/mastodon-reject-activity.json")
      |> Jason.decode!()
      |> Map.put("actor", followed.ap_id)
      |> Map.put("object", follow_activity.data["id"])

    {:ok, %Activity{data: _}} = Transmogrifier.handle_incoming(reject_data)

    follower = User.get_cached_by_id(follower.id)

    assert User.following?(follower, followed) == false
  end

  describe "when accept/reject references a transient activity" do
    test "it handles accept activities that do not contain an ID key" do
      follower = insert(:user)
      followed = insert(:user, is_locked: true)

      pending_follow =
        insert(:follow_activity, follower: follower, followed: followed, state: "pending")

      refute User.following?(follower, followed)

      without_id = Map.delete(pending_follow.data, "id")

      reject_data =
        File.read!("test/fixtures/mastodon-reject-activity.json")
        |> Jason.decode!()
        |> Map.put("actor", followed.ap_id)
        |> Map.delete("id")
        |> Map.put("object", without_id)

      {:ok, %Activity{data: _}} = Transmogrifier.handle_incoming(reject_data)

      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, followed)
      assert Utils.fetch_latest_follow(follower, followed).data["state"] == "reject"
    end

    test "it handles reject activities that do not contain an ID key" do
      follower = insert(:user)
      followed = insert(:user)
      {:ok, follower, followed} = User.follow(follower, followed)
      {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)
      assert Utils.fetch_latest_follow(follower, followed).data["state"] == "accept"
      assert User.following?(follower, followed)

      without_id = Map.delete(follow_activity.data, "id")

      reject_data =
        File.read!("test/fixtures/mastodon-reject-activity.json")
        |> Jason.decode!()
        |> Map.put("actor", followed.ap_id)
        |> Map.delete("id")
        |> Map.put("object", without_id)

      {:ok, %Activity{data: _}} = Transmogrifier.handle_incoming(reject_data)

      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, followed)
      assert Utils.fetch_latest_follow(follower, followed).data["state"] == "reject"
    end

    test "it does not accept follows that are not in pending or accepted" do
      follower = insert(:user)
      followed = insert(:user, is_locked: true)

      rejected_follow =
        insert(:follow_activity, follower: follower, followed: followed, state: "reject")

      refute User.following?(follower, followed)

      without_id = Map.delete(rejected_follow.data, "id")

      accept_data =
        File.read!("test/fixtures/mastodon-accept-activity.json")
        |> Jason.decode!()
        |> Map.put("actor", followed.ap_id)
        |> Map.put("object", without_id)

      {:error, _} = Transmogrifier.handle_incoming(accept_data)

      refute User.following?(follower, followed)
    end
  end

  test "it rejects activities without a valid ID" do
    user = insert(:user)

    data =
      File.read!("test/fixtures/mastodon-follow-activity.json")
      |> Jason.decode!()
      |> Map.put("object", user.ap_id)
      |> Map.put("id", "")

    :error = Transmogrifier.handle_incoming(data)
  end
end
