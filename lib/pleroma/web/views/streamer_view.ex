# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.StreamerView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Conversation.Participation
  alias Pleroma.Notification
  alias Pleroma.User
  alias Pleroma.Web.MastodonAPI.NotificationView

  def render("update.json", %Activity{} = activity, %User{} = user, topic) do
    %{
      stream: [topic],
      event: "update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity,
          for: user
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("status_update.json", %Activity{} = activity, %User{} = user, topic) do
    activity = Activity.get_create_by_object_ap_id_with_object(activity.object.data["id"])

    %{
      stream: [topic],
      event: "status.update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity,
          for: user
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("notification.json", %Notification{} = notify, %User{} = user, topic) do
    %{
      stream: [topic],
      event: "notification",
      payload:
        NotificationView.render(
          "show.json",
          %{notification: notify, for: user}
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("update.json", %Activity{} = activity, topic) do
    %{
      stream: [topic],
      event: "update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("status_update.json", %Activity{} = activity, topic) do
    activity = Activity.get_create_by_object_ap_id_with_object(activity.object.data["id"])

    %{
      stream: [topic],
      event: "status.update",
      payload:
        Pleroma.Web.MastodonAPI.StatusView.render(
          "show.json",
          activity: activity
        )
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render(
        "follow_relationships_update.json",
        %{follower: follower, following: following, state: state},
        topic
      ) do
    # This is streamed out to the _follower_
    # Thus the full details of the follower should be sent out unchecked,
    # but details of the following user must obey user-indicated preferences
    following_followers = if following.hide_followers_count, do: 0, else: following.follower_count
    following_following = if following.hide_follows_count, do: 0, else: following.following_count

    %{
      stream: [topic],
      event: "pleroma:follow_relationships_update",
      payload:
        %{
          state: state,
          follower: %{
            id: follower.id,
            follower_count: follower.follower_count,
            following_count: follower.following_count
          },
          following: %{
            id: following.id,
            follower_count: following_followers,
            following_count: following_following
          }
        }
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end

  def render("conversation.json", %Participation{} = participation, topic) do
    %{
      stream: [topic],
      event: "conversation",
      payload:
        Pleroma.Web.MastodonAPI.ConversationView.render("participation.json", %{
          participation: participation,
          for: participation.user
        })
        |> Jason.encode!()
    }
    |> Jason.encode!()
  end
end
