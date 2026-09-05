# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationViewTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Conversation.Participation
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.ConversationView

  import Pleroma.Factory

  test "represents a Mastodon Conversation entity" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, parent} = CommonAPI.post(user, %{status: "parent"})

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "hey @#{other_user.nickname}",
        visibility: "direct",
        in_reply_to_id: parent.id
      })

    {:ok, _reply_activity} =
      CommonAPI.post(user, %{status: "hu", visibility: "public", in_reply_to_id: parent.id})

    [%{entry: participation}] = Participation.for_user_with_pagination(user)

    assert participation

    conversation =
      ConversationView.render("participation.json", %{participation: participation, for: user})

    assert conversation.id == participation.id |> to_string()
    assert conversation.last_status.id == activity.id
    assert conversation.last_status.account.id == user.id

    assert [account] = conversation.accounts
    assert account.id == other_user.id

    assert conversation.last_status.pleroma.direct_conversation_id == participation.id
  end

  test "does not leak post when user lost access rights after posting" do
    u1 = insert(:user, local: true)
    u2 = insert(:user, local: true)

    CommonAPI.follow(u2, u1)

    {:ok, act_op} = CommonAPI.post(u1, %{status: "hiii @#{u2.nickname}", visibility: "direct"})
    act_flw = insert(:followers_only_note_activity, %{user: u1, context: act_op.data["context"]})

    assert Visibility.visible_for_user?(act_flw, u2)
    assert act_flw.data["context"] == act_op.data["context"]

    # ensure last_bump comes from follower-only post
    [%{entry: %Participation{} = p2_init}] = Participation.for_user_with_pagination(u2)

    {:ok, p2_before} =
      Ecto.Changeset.change(p2_init, %{last_bump: act_flw.id})
      |> Repo.update()

    assert p2_before.user_id == u2.id
    assert p2_before.last_bump == act_flw.id

    CommonAPI.unfollow(u2, u1)
    refute Visibility.visible_for_user?(act_flw, u2)

    [%{entry: %Participation{} = p2_after}] = Participation.for_user_with_pagination(u2)

    conversation =
      ConversationView.render("participation.json", %{participation: p2_after, for: u2})

    refute conversation.last_status.id == act_flw.id
    assert conversation.last_status.id == act_op.id
  end
end
