# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation.ParticipationTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Conversation.Participation
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI

  defp user_participations(user, opts \\ %{}) do
    Participation.for_user_with_pagination(user, opts)
    |> Pleroma.Pagination.unwrap()
    |> Participation.preload_last_activity_id_and_filter()
  end

  defp user_participations_raw(user, opts \\ %{}) do
    Participation.for_user_with_pagination(user, opts)
    |> Pleroma.Pagination.unwrap()
  end

  test "getting a participation will also preload things" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _activity} =
      CommonAPI.post(user, %{status: "Hey @#{other_user.nickname}.", visibility: "direct"})

    [participation] = user_participations(user)

    participation = Participation.get(participation.id, preload: [:conversation])

    assert %Pleroma.Conversation{} = participation.conversation
  end

  test "for a new conversation or a reply, it doesn't mark the author's participation as unread" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, op_activity} =
      CommonAPI.post(user, %{status: "Hey @#{other_user.nickname}.", visibility: "direct"})

    user = User.get_cached_by_id(user.id)
    other_user = User.get_cached_by_id(other_user.id)

    [%{read: true}] = user_participations(user)
    [%{read: false}] = user_participations(other_user)
    assert Participation.unread_count(user) == 0
    assert Participation.unread_count(other_user) == 1

    {:ok, _} =
      CommonAPI.post(other_user, %{
        status: "Hey @#{user.nickname}.",
        visibility: "direct",
        in_reply_to_id: op_activity.id
      })

    user = User.get_cached_by_id(user.id)
    other_user = User.get_cached_by_id(other_user.id)

    [%{read: false}] = user_participations(user)
    [%{read: true}] = user_participations(other_user)

    assert Participation.unread_count(user) == 1
    assert Participation.unread_count(other_user) == 0
  end

  test "for a new conversation, it sets the recipents of the participation" do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{status: "Hey @#{other_user.nickname}.", visibility: "direct"})

    user = User.get_cached_by_id(user.id)
    other_user = User.get_cached_by_id(other_user.id)
    [participation] = user_participations(user)
    participation = Pleroma.Repo.preload(participation, :recipients)

    assert length(participation.recipients) == 2
    assert user in participation.recipients
    assert other_user in participation.recipients

    # Mentioning another user in the same conversation will not add a new recipients.

    {:ok, _activity} =
      CommonAPI.post(user, %{
        in_reply_to_status_id: activity.id,
        status: "Hey @#{third_user.nickname}.",
        visibility: "direct"
      })

    [participation] = user_participations(user)
    participation = Pleroma.Repo.preload(participation, :recipients)

    assert length(participation.recipients) == 2
  end

  test "it creates a participation for a conversation and a user" do
    user = insert(:user)
    conversation = insert(:conversation)

    %Pleroma.Activity{id: status_id} =
      insert(:direct_note_activity, %{user: user, context: conversation.ap_id})

    {:ok, %Participation{} = participation} =
      Participation.create_or_bump(user, conversation, status_id)

    {:ok, participation} = time_travel(participation, -2)

    p1_lai = Participation.last_activity_id(participation)

    assert participation.user_id == user.id
    assert participation.conversation_id == conversation.id
    assert p1_lai == status_id

    # Creating again returns the same participation
    {:ok, %Participation{} = participation_two} =
      Participation.create_or_bump(user, conversation, status_id)

    assert participation.id == participation_two.id
    refute participation.updated_at == participation_two.updated_at
    assert p1_lai = Participation.last_activity_id(participation_two)

    # Creating again with differnt status updates existing participation
    %Pleroma.Activity{id: new_status_id} =
      insert(:direct_note_activity, %{user: user, context: conversation.ap_id})

    {:ok, %Participation{} = participation_three} =
      Participation.create_or_bump(user, conversation, new_status_id)

    p3_lai = Participation.last_activity_id(participation_three)

    assert participation.id == participation_two.id
    refute participation.updated_at == participation_three.updated_at
    refute p1_lai == p3_lai
    assert p3_lai == new_status_id
  end

  test "recreating an existing participations sets it to unread" do
    participation = insert(:participation, %{read: true})

    {:ok, participation} =
      Participation.create_or_bump(
        participation.user,
        participation.conversation,
        participation.last_bump
      )

    refute participation.read
  end

  test "it marks a participation as read" do
    participation = insert(:participation, %{updated_at: ~N[2017-07-17 17:09:58], read: false})
    {:ok, updated_participation} = Participation.mark_as_read(participation)

    assert updated_participation.read
    assert :gt = NaiveDateTime.compare(updated_participation.updated_at, participation.updated_at)
  end

  test "it marks a participation as unread" do
    participation = insert(:participation, %{read: true})
    {:ok, participation} = Participation.mark_as_unread(participation)

    refute participation.read
  end

  test "it marks all the user's participations as read" do
    user = insert(:user)
    other_user = insert(:user)
    participation1 = insert(:participation, %{read: false, user: user})
    participation2 = insert(:participation, %{read: false, user: user})
    participation3 = insert(:participation, %{read: false, user: other_user})

    {:ok, _, [%{read: true}, %{read: true}]} = Participation.mark_all_as_read(user)

    assert Participation.get(participation1.id).read == true
    assert Participation.get(participation2.id).read == true
    assert Participation.get(participation3.id).read == false
  end

  test "gets all the participations for a user, ordered by last bump descending" do
    user = insert(:user)
    {:ok, activity_one} = CommonAPI.post(user, %{status: "x", visibility: "direct"})
    {:ok, activity_two} = CommonAPI.post(user, %{status: "x", visibility: "direct"})

    {:ok, activity_three} =
      CommonAPI.post(user, %{
        status: "x",
        visibility: "direct",
        in_reply_to_status_id: activity_one.id
      })

    assert [participation_one, participation_two] = user_participations(user)

    object2 = Pleroma.Object.normalize(activity_two, fetch: false)
    object3 = Pleroma.Object.normalize(activity_three, fetch: false)

    user = Repo.get(Pleroma.User, user.id)
    participation_one = Pleroma.Repo.preload(participation_one, :recipients)

    assert participation_one.conversation.ap_id == object3.data["context"]
    assert participation_two.conversation.ap_id == object2.data["context"]
    assert participation_one.recipients == [user]

    # Pagination
    assert [%{id: pid, entry: participation_one}] =
             Participation.for_user_with_pagination(user, %{limit: 1})

    assert participation_one.conversation.ap_id == object3.data["context"]
    assert pid == Participation.last_activity_id(participation_one)

    # Check last_status id
    assert [participation_one] = user_participations(user, %{limit: 1})

    assert Participation.last_activity_id(participation_one) == activity_three.id
  end

  test "Doesn't show empty conversations" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})
    [participation] = user_participations(user)

    assert Participation.last_activity_id(participation) == activity.id

    {:ok, _} = CommonAPI.delete(activity.id, user)

    [] = user_participations(user)
  end

  test "it sets recipients, always keeping the owner of the participation even when not explicitly set" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})
    [participation] = user_participations(user)

    participation = Repo.preload(participation, :recipients)
    user = User.get_cached_by_id(user.id)

    assert participation.recipients |> length() == 1
    assert user in participation.recipients

    {:ok, participation} = Participation.set_recipients(participation, [other_user.id])

    assert participation.recipients |> length() == 2
    assert user in participation.recipients
    assert other_user in participation.recipients
  end

  test "updates last_bump when posting" do
    actor = insert(:user, local: true)
    other = insert(:user)

    {:ok, create1} =
      CommonAPI.post(actor, %{status: "hi @#{other.nickname}", visibility: "direct"})

    [participation] = user_participations(actor)
    assert participation.last_bump == create1.id

    {:ok, create2} =
      CommonAPI.post(actor, %{
        status: "@#{other.nickname} how are you doing?",
        visibility: "direct",
        in_reply_to_status_id: create1.id
      })

    [participation] = user_participations(actor)
    assert participation.last_bump == create2.id
    # new message was from user themself
    assert participation.read == true
  end

  test "updates last_bump and marks as unread when receiving new remote message" do
    actor = insert(:user, local: true)
    other = insert(:user, local: false)

    {:ok, create1} =
      CommonAPI.post(actor, %{status: "hi @#{other.nickname}", visibility: "direct"})

    [participation] = user_participations(actor)
    assert participation.last_bump == create1.id

    Participation.mark_as_read(participation)

    {:ok, create2} =
      Transmogrifier.handle_incoming(%{
        "id" => "#{other.ap_id}/creates/1234",
        "type" => "Create",
        "actor" => other.ap_id,
        "to" => [actor.ap_id],
        "object" => %{
          "id" => "#{other.ap_id}/notes/1234",
          "type" => "Note",
          "attributedTo" => other.ap_id,
          "to" => [actor.ap_id],
          "content" => "hiya, what’s up?",
          "context" => create1.data["context"],
          "tag" => [
            %{
              "type" => "Mention",
              "name" => "@#{actor.nickname}@#{URI.parse(actor.ap_id) |> Map.get(:host)}",
              "href" => actor.ap_id
            }
          ]
        }
      })

    [participation] = user_participations(actor)
    assert participation.last_bump == create2.id
    assert participation.read == false
  end

  test "does not update last_bump when user cannot see new post" do
    u1 = insert(:user, local: true)
    u2 = insert(:user, local: true)
    u3 = insert(:user, local: true)
    u4 = insert(:user)

    to_full = [u1.nickname, u2.nickname, u3.nickname, u4.nickname]
    to_subs = [u1.nickname, u2.nickname, u4.nickname]

    {:ok, activity_op} =
      CommonAPI.post(u1, %{status: "blaa blih blub", visibility: "direct", to: to_full})

    assert Visibility.visible_for_user?(activity_op, u1)
    assert Visibility.visible_for_user?(activity_op, u2)
    assert Visibility.visible_for_user?(activity_op, u3)
    assert Visibility.visible_for_user?(activity_op, u4)

    [p1] = user_participations(u1)
    [p2] = user_participations(u2)
    [p3] = user_participations(u3)

    assert p1.user_id == u1.id
    assert p1.last_bump == activity_op.id

    assert p2.user_id == u2.id
    assert p2.last_bump == p1.last_bump

    assert p3.user_id == u3.id
    assert p3.last_bump == p1.last_bump

    {:ok, activity_subset} =
      CommonAPI.post(u2, %{
        status: "waff?",
        visibility: "direct",
        to: to_subs,
        in_reply_to_status_id: activity_op.id
      })

    assert Visibility.visible_for_user?(activity_subset, u1)
    assert Visibility.visible_for_user?(activity_subset, u2)
    refute Visibility.visible_for_user?(activity_subset, u3)
    assert Visibility.visible_for_user?(activity_subset, u4)

    [p1] = user_participations(u1)
    [p2] = user_participations(u2)
    [p3] = user_participations(u3)

    assert p1.user_id == u1.id
    assert p1.last_bump == activity_subset.id

    assert p2.user_id == u2.id
    assert p2.last_bump == p1.last_bump

    assert p3.user_id == u3.id
    assert p3.last_bump == activity_op.id

    refute p3.last_bump == p1.last_bump
  end

  describe "blocking" do
    test "when the user blocks a recipient, the existing conversations with them are marked as read" do
      blocker = insert(:user)
      blocked = insert(:user)
      third_user = insert(:user)

      {:ok, _direct1} =
        CommonAPI.post(third_user, %{
          status: "Hi @#{blocker.nickname}",
          visibility: "direct"
        })

      {:ok, _direct2} =
        CommonAPI.post(third_user, %{
          status: "Hi @#{blocker.nickname}, @#{blocked.nickname}",
          visibility: "direct"
        })

      {:ok, _direct3} =
        CommonAPI.post(blocked, %{
          status: "Hi @#{blocker.nickname}",
          visibility: "direct"
        })

      {:ok, _direct4} =
        CommonAPI.post(blocked, %{
          status: "Hi @#{blocker.nickname}, @#{third_user.nickname}",
          visibility: "direct"
        })

      assert [%{read: false}, %{read: false}, %{read: false}, %{read: false}] =
               user_participations_raw(blocker)

      assert length(user_participations(blocker)) == 4
      assert Participation.unread_count(blocker) == 4

      {:ok, _user_relationship} = User.block(blocker, blocked)

      # The conversations with the blocked user are marked as read
      assert [%{read: true}, %{read: true}, %{read: true}, %{read: false}] =
               user_participations_raw(blocker)

      # and they are filtered from API responses
      assert length(user_participations(blocker)) == 1
      assert Participation.unread_count(blocker) == 1

      # The conversation is not marked as read for the blocked user
      assert [_, _, %{read: false}] = user_participations(blocked)
      assert Participation.unread_count(blocker) == 1

      # The conversation is not marked as read for the third user
      assert [%{read: false}, _, _] = user_participations(third_user)
      assert Participation.unread_count(third_user) == 1
    end

    test "the new conversation with the blocked user is not marked as unread " do
      blocker = insert(:user)
      blocked = insert(:user)
      third_user = insert(:user)

      {:ok, _user_relationship} = User.block(blocker, blocked)

      # When the blocked user is the author
      {:ok, _direct1} =
        CommonAPI.post(blocked, %{
          status: "Hi @#{blocker.nickname}",
          visibility: "direct"
        })

      assert [%{read: true}] = user_participations_raw(blocker)
      assert [] == user_participations(blocker)
      assert Participation.unread_count(blocker) == 0

      # When the blocked user is a recipient
      {:ok, _direct2} =
        CommonAPI.post(third_user, %{
          status: "Hi @#{blocker.nickname}, @#{blocked.nickname}",
          visibility: "direct"
        })

      assert [%{read: true}, %{read: true}] = user_participations_raw(blocker)
      assert [] == user_participations(blocker)
      assert Participation.unread_count(blocker) == 0

      assert [%{read: false}, _] = user_participations(blocked)
      assert Participation.unread_count(blocked) == 1
    end

    test "the conversation with the blocked user is not marked as unread on a reply" do
      blocker = insert(:user)
      blocked = insert(:user)
      third_user = insert(:user)

      {:ok, direct1} =
        CommonAPI.post(blocker, %{
          status: "Hi @#{third_user.nickname}, @#{blocked.nickname}",
          visibility: "direct"
        })

      {:ok, _user_relationship} = User.block(blocker, blocked)
      assert [%{read: true}] = user_participations(blocker)

      assert Participation.unread_count(blocker) == 0

      # When it's a reply from the blocked user
      {:ok, direct2} =
        CommonAPI.post(blocked, %{
          status: "@#{third_user.nickname}, #{blocker.nickname} reply",
          visibility: "direct",
          in_reply_to_id: direct1.id
        })

      assert [%{read: true}] = user_participations(blocker)

      assert Participation.unread_count(blocker) == 0

      # When it's a reply from the third user to the blocked user
      {:ok, _direct3} =
        CommonAPI.post(third_user, %{
          status: "reply",
          visibility: "direct",
          in_reply_to_id: direct2.id
        })

      assert [%{read: true}] = user_participations(blocker)
      assert Participation.unread_count(blocker) == 0

      # Marked as unread for the blocked user
      assert [%{read: false}] = user_participations(blocked)

      assert Participation.unread_count(blocked) == 1
    end
  end

  test "deletes a conversation" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, _activity} =
      CommonAPI.post(user, %{status: "Hey @#{other_user.nickname}.", visibility: "direct"})

    assert [participation] = user_participations(other_user)
    assert {:ok, _} = Participation.delete(participation)
    assert [] == user_participations(other_user)
  end
end
