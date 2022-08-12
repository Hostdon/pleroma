# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.NotificationViewTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Pipeline
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.AdminAPI.ReportView
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.NotificationView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MediaProxy
  import Pleroma.Factory

  defp test_notifications_rendering(notifications, user, expected_result) do
    result = NotificationView.render("index.json", %{notifications: notifications, for: user})

    assert expected_result == result

    result =
      NotificationView.render("index.json", %{
        notifications: notifications,
        for: user,
        relationships: nil
      })

    assert expected_result == result
  end

  test "Mention notification" do
    user = insert(:user)
    mentioned_user = insert(:user)
    {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{mentioned_user.nickname}"})
    {:ok, [notification]} = Notification.create_notifications(activity)
    user = User.get_cached_by_id(user.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "mention",
      account:
        AccountView.render("show.json", %{
          user: user,
          for: mentioned_user
        }),
      status: StatusView.render("show.json", %{activity: activity, for: mentioned_user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], mentioned_user, [expected])
  end

  test "Favourite notification" do
    user = insert(:user)
    another_user = insert(:user)
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(another_user, create_activity.id)
    {:ok, [notification]} = Notification.create_notifications(favorite_activity)
    create_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "favourite",
      account: AccountView.render("show.json", %{user: another_user, for: user}),
      status: StatusView.render("show.json", %{activity: create_activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "Reblog notification" do
    user = insert(:user)
    another_user = insert(:user)
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, reblog_activity} = CommonAPI.repeat(create_activity.id, another_user)
    {:ok, [notification]} = Notification.create_notifications(reblog_activity)
    reblog_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "reblog",
      account: AccountView.render("show.json", %{user: another_user, for: user}),
      status: StatusView.render("show.json", %{activity: reblog_activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "Follow notification" do
    follower = insert(:user)
    followed = insert(:user)
    {:ok, follower, followed, _activity} = CommonAPI.follow(follower, followed)
    notification = Notification |> Repo.one() |> Repo.preload(:activity)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "follow",
      account: AccountView.render("show.json", %{user: follower, for: followed}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], followed, [expected])

    User.perform(:delete, follower)
    refute Repo.one(Notification)
  end

  test "Move notification" do
    old_user = insert(:user)
    new_user = insert(:user, also_known_as: [old_user.ap_id])
    follower = insert(:user)

    User.follow(follower, old_user)
    Pleroma.Web.ActivityPub.ActivityPub.move(old_user, new_user)
    Pleroma.Tests.ObanHelpers.perform_all()

    old_user = refresh_record(old_user)
    new_user = refresh_record(new_user)

    [notification] = Notification.for_user(follower)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "move",
      account: AccountView.render("show.json", %{user: old_user, for: follower}),
      target: AccountView.render("show.json", %{user: new_user, for: follower}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], follower, [expected])
  end

  test "EmojiReact notification" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})
    {:ok, _activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

    activity = Repo.get(Activity, activity.id)

    [notification] = Notification.for_user(user)

    assert notification

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "pleroma:emoji_reaction",
      emoji: "☕",
      emoji_url: nil,
      account: AccountView.render("show.json", %{user: other_user, for: user}),
      status: StatusView.render("show.json", %{activity: activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "EmojiReact notification with custom emoji" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#morb"})
    {:ok, _activity} = CommonAPI.react_with_emoji(activity.id, other_user, ":100a:")

    activity = Repo.get(Activity, activity.id)

    [notification] = Notification.for_user(user)

    assert notification

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "pleroma:emoji_reaction",
      emoji: ":100a:",
      emoji_url: "http://localhost:4001/emoji/100a.png",
      account: AccountView.render("show.json", %{user: other_user, for: user}),
      status: StatusView.render("show.json", %{activity: activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "EmojiReact notification with remote custom emoji" do
    proxyBaseUrl = "https://cache.pleroma.social"
    clear_config([:media_proxy, :base_url], proxyBaseUrl)

    for testProxy <- [true, false] do
      clear_config([:media_proxy, :enabled], testProxy)

      user = insert(:user)
      other_user = insert(:user, local: false)

      {:ok, activity} = CommonAPI.post(user, %{status: "#morb"})

      {:ok, emoji_react, _} =
        Builder.emoji_react(other_user, Object.normalize(activity, fetch: false), ":100a:")

      remoteUrl = "http://evil.website/emoji/100a.png"
      [tag] = emoji_react["tag"]
      tag = put_in(tag["id"], remoteUrl)
      tag = put_in(tag["icon"]["url"], remoteUrl)
      emoji_react = put_in(emoji_react["tag"], [tag])

      {:ok, _activity, _} = Pipeline.common_pipeline(emoji_react, local: false)

      activity = Repo.get(Activity, activity.id)

      [notification] = Notification.for_user(user)

      assert notification

      expected = %{
        id: to_string(notification.id),
        pleroma: %{is_seen: false, is_muted: false},
        type: "pleroma:emoji_reaction",
        emoji: ":100a:",
        emoji_url: if(testProxy, do: MediaProxy.encode_url(remoteUrl), else: remoteUrl),
        account: AccountView.render("show.json", %{user: other_user, for: user}),
        status: StatusView.render("show.json", %{activity: activity, for: user}),
        created_at: Utils.to_masto_date(notification.inserted_at)
      }

      test_notifications_rendering([notification], user, [expected])
    end
  end

  test "Poll notification" do
    user = insert(:user)
    activity = insert(:question_activity, user: user)
    {:ok, [notification]} = Notification.create_poll_notifications(activity)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "poll",
      account:
        AccountView.render("show.json", %{
          user: user,
          for: user
        }),
      status: StatusView.render("show.json", %{activity: activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end

  test "Report notification" do
    reporting_user = insert(:user)
    reported_user = insert(:user)
    {:ok, moderator_user} = insert(:user) |> User.admin_api_update(%{is_moderator: true})

    {:ok, activity} = CommonAPI.report(reporting_user, %{account_id: reported_user.id})
    {:ok, [notification]} = Notification.create_notifications(activity)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: false, is_muted: false},
      type: "pleroma:report",
      account: AccountView.render("show.json", %{user: reporting_user, for: moderator_user}),
      created_at: Utils.to_masto_date(notification.inserted_at),
      report: ReportView.render("show.json", Report.extract_report_info(activity))
    }

    test_notifications_rendering([notification], moderator_user, [expected])
  end

  test "muted notification" do
    user = insert(:user)
    another_user = insert(:user)

    {:ok, _} = Pleroma.UserRelationship.create_mute(user, another_user)
    {:ok, create_activity} = CommonAPI.post(user, %{status: "hey"})
    {:ok, favorite_activity} = CommonAPI.favorite(another_user, create_activity.id)
    {:ok, [notification]} = Notification.create_notifications(favorite_activity)
    create_activity = Activity.get_by_id(create_activity.id)

    expected = %{
      id: to_string(notification.id),
      pleroma: %{is_seen: true, is_muted: true},
      type: "favourite",
      account: AccountView.render("show.json", %{user: another_user, for: user}),
      status: StatusView.render("show.json", %{activity: create_activity, for: user}),
      created_at: Utils.to_masto_date(notification.inserted_at)
    }

    test_notifications_rendering([notification], user, [expected])
  end
end
