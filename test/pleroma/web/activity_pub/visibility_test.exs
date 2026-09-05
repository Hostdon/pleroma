# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.VisibilityTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory

  setup do
    user = insert(:user)
    mentioned = insert(:user)
    following = insert(:user)
    unrelated = insert(:user)
    remote = insert(:user, local: false)
    {:ok, following, user} = Pleroma.User.follow(following, user)
    {:ok, list} = Pleroma.List.create(%{title: "foo"}, user)
    list_ap_id = user.ap_id <> "/lists/" <> to_string(list.id)

    Pleroma.List.follow(list, unrelated)

    {:ok, public} =
      CommonAPI.post(user, %{status: "@#{mentioned.nickname}", visibility: "public"})

    {:ok, private} =
      CommonAPI.post(user, %{status: "@#{mentioned.nickname}", visibility: "private"})

    {:ok, direct} =
      CommonAPI.post(user, %{status: "@#{mentioned.nickname}", visibility: "direct"})

    {:ok, unlisted} =
      CommonAPI.post(user, %{status: "@#{mentioned.nickname}", visibility: "unlisted"})

    {:ok, local} = CommonAPI.post(user, %{status: "@#{mentioned.nickname}", visibility: "local"})

    # list visibility is no longer supported, but we want to check any
    # leftover entreis are handled sensibly, so we nned to manually fix up the data
    {:ok, list_activity} =
      CommonAPI.post(user, %{
        status: "@#{mentioned.nickname}",
        visibility: "direct"
      })

    list_object = Object.normalize(list_activity)
    {:ok, list_object} = Object.update_data(list_object, %{"listMessage" => list_ap_id})
    list_activity = %{list_activity | object: list_object}

    %{
      public: public,
      private: private,
      direct: direct,
      unlisted: unlisted,
      user: user,
      mentioned: mentioned,
      following: following,
      unrelated: unrelated,
      list: list_activity,
      local: local,
      remote: remote
    }
  end

  test "is_direct?", %{
    public: public,
    private: private,
    direct: direct,
    unlisted: unlisted,
    list: list,
    local: local
  } do
    assert Visibility.is_direct?(direct)
    refute Visibility.is_direct?(public)
    refute Visibility.is_direct?(private)
    refute Visibility.is_direct?(unlisted)
    refute Visibility.is_direct?(local)
    assert Visibility.is_direct?(list)
  end

  test "is_public?", %{
    public: public,
    private: private,
    direct: direct,
    unlisted: unlisted,
    local: local,
    list: list
  } do
    refute Visibility.is_public?(direct)
    assert Visibility.is_public?(public)
    refute Visibility.is_public?(private)
    assert Visibility.is_public?(unlisted)
    assert Visibility.is_public?(local)
    refute Visibility.is_public?(list)
  end

  test "is_private?", %{
    public: public,
    private: private,
    direct: direct,
    unlisted: unlisted,
    list: list,
    local: local
  } do
    refute Visibility.is_private?(direct)
    refute Visibility.is_private?(public)
    assert Visibility.is_private?(private)
    refute Visibility.is_private?(unlisted)
    refute Visibility.is_private?(list)
    refute Visibility.is_private?(local)
  end

  test "visible_for_user? Activity", %{
    public: public,
    private: private,
    direct: direct,
    unlisted: unlisted,
    user: user,
    mentioned: mentioned,
    following: following,
    unrelated: unrelated,
    list: list,
    local: local,
    remote: remote
  } do
    # All visible to author

    assert Visibility.visible_for_user?(public, user)
    assert Visibility.visible_for_user?(private, user)
    assert Visibility.visible_for_user?(unlisted, user)
    assert Visibility.visible_for_user?(direct, user)
    assert Visibility.visible_for_user?(list, user)
    assert Visibility.visible_for_user?(local, user)

    # All visible to a mentioned user

    assert Visibility.visible_for_user?(public, mentioned)
    assert Visibility.visible_for_user?(private, mentioned)
    assert Visibility.visible_for_user?(unlisted, mentioned)
    assert Visibility.visible_for_user?(direct, mentioned)
    assert Visibility.visible_for_user?(list, mentioned)
    assert Visibility.visible_for_user?(local, mentioned)

    # DM not visible for just follower

    assert Visibility.visible_for_user?(public, following)
    assert Visibility.visible_for_user?(private, following)
    assert Visibility.visible_for_user?(unlisted, following)
    refute Visibility.visible_for_user?(direct, following)
    refute Visibility.visible_for_user?(list, following)
    assert Visibility.visible_for_user?(local, following)

    # Public and unlisted visible for unrelated user

    assert Visibility.visible_for_user?(public, unrelated)
    assert Visibility.visible_for_user?(unlisted, unrelated)
    refute Visibility.visible_for_user?(private, unrelated)
    refute Visibility.visible_for_user?(direct, unrelated)
    assert Visibility.visible_for_user?(local, unrelated)

    # Public and unlisted visible for unauthenticated

    assert Visibility.visible_for_user?(public, nil)
    assert Visibility.visible_for_user?(unlisted, nil)
    refute Visibility.visible_for_user?(private, nil)
    refute Visibility.visible_for_user?(direct, nil)
    refute Visibility.visible_for_user?(local, nil)

    # Local not visible to remote user
    refute Visibility.visible_for_user?(local, remote)
  end

  test "visible_for_user? Object", %{
    public: public,
    private: private,
    direct: direct,
    unlisted: unlisted,
    user: user,
    mentioned: mentioned,
    following: following,
    unrelated: unrelated,
    list: list,
    local: local,
    remote: remote
  } do
    public = Object.normalize(public)
    private = Object.normalize(private)
    unlisted = Object.normalize(unlisted)
    direct = Object.normalize(direct)
    list = Object.normalize(list)
    local = Object.normalize(local)

    # All visible to author

    assert Visibility.visible_for_user?(public, user)
    assert Visibility.visible_for_user?(private, user)
    assert Visibility.visible_for_user?(unlisted, user)
    assert Visibility.visible_for_user?(direct, user)
    assert Visibility.visible_for_user?(list, user)

    # All visible to a mentioned user

    assert Visibility.visible_for_user?(public, mentioned)
    assert Visibility.visible_for_user?(private, mentioned)
    assert Visibility.visible_for_user?(unlisted, mentioned)
    assert Visibility.visible_for_user?(direct, mentioned)
    assert Visibility.visible_for_user?(list, mentioned)

    # DM not visible for just follower

    assert Visibility.visible_for_user?(public, following)
    assert Visibility.visible_for_user?(private, following)
    assert Visibility.visible_for_user?(unlisted, following)
    refute Visibility.visible_for_user?(direct, following)
    refute Visibility.visible_for_user?(list, following)

    # Public and unlisted visible for unrelated user

    assert Visibility.visible_for_user?(public, unrelated)
    assert Visibility.visible_for_user?(unlisted, unrelated)
    refute Visibility.visible_for_user?(private, unrelated)
    refute Visibility.visible_for_user?(direct, unrelated)

    # Public and unlisted visible for unauthenticated

    assert Visibility.visible_for_user?(public, nil)
    assert Visibility.visible_for_user?(unlisted, nil)
    refute Visibility.visible_for_user?(private, nil)
    refute Visibility.visible_for_user?(direct, nil)
    refute Visibility.visible_for_user?(local, nil)

    # Local posts to remote
    refute Visibility.visible_for_user?(local, remote)
    # Visible for a list member
    # assert Visibility.visible_for_user?(list, unrelated)
  end

  test "doesn't die when the user doesn't exist",
       %{
         direct: direct,
         user: user
       } do
    Repo.delete(user)
    Pleroma.User.invalidate_cache(user)
    refute Visibility.is_private?(direct)
  end

  test "get_visibility", %{
    public: public,
    private: private,
    direct: direct,
    unlisted: unlisted,
    list: list
  } do
    assert Visibility.get_visibility(public) == "public"
    assert Visibility.get_visibility(private) == "private"
    assert Visibility.get_visibility(direct) == "direct"
    assert Visibility.get_visibility(unlisted) == "unlisted"
    # legacy, no longer supported visibility type doesn't leak out now
    assert Visibility.get_visibility(list) == "direct"
  end

  test "get_visibility with directMessage flag" do
    assert Visibility.get_visibility(%{data: %{"directMessage" => true}}) == "direct"
  end

  test "get_visibility treats legacy list messages as direct" do
    assert Visibility.get_visibility(%{data: %{"listMessage" => ""}}) == "direct"
  end
end
