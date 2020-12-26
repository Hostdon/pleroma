# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserTest do
  alias Pleroma.Activity
  alias Pleroma.Builders.UserBuilder
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :account_activation_required])

  describe "service actors" do
    test "returns updated invisible actor" do
      uri = "#{Pleroma.Web.Endpoint.url()}/relay"
      followers_uri = "#{uri}/followers"

      insert(
        :user,
        %{
          nickname: "relay",
          invisible: false,
          local: true,
          ap_id: uri,
          follower_address: followers_uri
        }
      )

      actor = User.get_or_create_service_actor_by_ap_id(uri, "relay")
      assert actor.invisible
    end

    test "returns relay user" do
      uri = "#{Pleroma.Web.Endpoint.url()}/relay"
      followers_uri = "#{uri}/followers"

      assert %User{
               nickname: "relay",
               invisible: true,
               local: true,
               ap_id: ^uri,
               follower_address: ^followers_uri
             } = User.get_or_create_service_actor_by_ap_id(uri, "relay")

      assert capture_log(fn ->
               refute User.get_or_create_service_actor_by_ap_id("/relay", "relay")
             end) =~ "Cannot create service actor:"
    end

    test "returns invisible actor" do
      uri = "#{Pleroma.Web.Endpoint.url()}/internal/fetch-test"
      followers_uri = "#{uri}/followers"
      user = User.get_or_create_service_actor_by_ap_id(uri, "internal.fetch-test")

      assert %User{
               nickname: "internal.fetch-test",
               invisible: true,
               local: true,
               ap_id: ^uri,
               follower_address: ^followers_uri
             } = user

      user2 = User.get_or_create_service_actor_by_ap_id(uri, "internal.fetch-test")
      assert user.id == user2.id
    end
  end

  describe "AP ID user relationships" do
    setup do
      {:ok, user: insert(:user)}
    end

    test "outgoing_relationships_ap_ids/1", %{user: user} do
      rel_types = [:block, :mute, :notification_mute, :reblog_mute, :inverse_subscription]

      ap_ids_by_rel =
        Enum.into(
          rel_types,
          %{},
          fn rel_type ->
            rel_records =
              insert_list(2, :user_relationship, %{source: user, relationship_type: rel_type})

            ap_ids = Enum.map(rel_records, fn rr -> Repo.preload(rr, :target).target.ap_id end)
            {rel_type, Enum.sort(ap_ids)}
          end
        )

      assert ap_ids_by_rel[:block] == Enum.sort(User.blocked_users_ap_ids(user))
      assert ap_ids_by_rel[:block] == Enum.sort(Enum.map(User.blocked_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:mute] == Enum.sort(User.muted_users_ap_ids(user))
      assert ap_ids_by_rel[:mute] == Enum.sort(Enum.map(User.muted_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:notification_mute] ==
               Enum.sort(User.notification_muted_users_ap_ids(user))

      assert ap_ids_by_rel[:notification_mute] ==
               Enum.sort(Enum.map(User.notification_muted_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:reblog_mute] == Enum.sort(User.reblog_muted_users_ap_ids(user))

      assert ap_ids_by_rel[:reblog_mute] ==
               Enum.sort(Enum.map(User.reblog_muted_users(user), & &1.ap_id))

      assert ap_ids_by_rel[:inverse_subscription] == Enum.sort(User.subscriber_users_ap_ids(user))

      assert ap_ids_by_rel[:inverse_subscription] ==
               Enum.sort(Enum.map(User.subscriber_users(user), & &1.ap_id))

      outgoing_relationships_ap_ids = User.outgoing_relationships_ap_ids(user, rel_types)

      assert ap_ids_by_rel ==
               Enum.into(outgoing_relationships_ap_ids, %{}, fn {k, v} -> {k, Enum.sort(v)} end)
    end
  end

  describe "when tags are nil" do
    test "tagging a user" do
      user = insert(:user, %{tags: nil})
      user = User.tag(user, ["cool", "dude"])

      assert "cool" in user.tags
      assert "dude" in user.tags
    end

    test "untagging a user" do
      user = insert(:user, %{tags: nil})
      user = User.untag(user, ["cool", "dude"])

      assert user.tags == []
    end
  end

  test "ap_id returns the activity pub id for the user" do
    user = UserBuilder.build()

    expected_ap_id = "#{Pleroma.Web.base_url()}/users/#{user.nickname}"

    assert expected_ap_id == User.ap_id(user)
  end

  test "ap_followers returns the followers collection for the user" do
    user = UserBuilder.build()

    expected_followers_collection = "#{User.ap_id(user)}/followers"

    assert expected_followers_collection == User.ap_followers(user)
  end

  test "ap_following returns the following collection for the user" do
    user = UserBuilder.build()

    expected_followers_collection = "#{User.ap_id(user)}/following"

    assert expected_followers_collection == User.ap_following(user)
  end

  test "returns all pending follow requests" do
    unlocked = insert(:user)
    locked = insert(:user, is_locked: true)
    follower = insert(:user)

    CommonAPI.follow(follower, unlocked)
    CommonAPI.follow(follower, locked)

    assert [] = User.get_follow_requests(unlocked)
    assert [activity] = User.get_follow_requests(locked)

    assert activity
  end

  test "doesn't return already accepted or duplicate follow requests" do
    locked = insert(:user, is_locked: true)
    pending_follower = insert(:user)
    accepted_follower = insert(:user)

    CommonAPI.follow(pending_follower, locked)
    CommonAPI.follow(pending_follower, locked)
    CommonAPI.follow(accepted_follower, locked)

    Pleroma.FollowingRelationship.update(accepted_follower, locked, :follow_accept)

    assert [^pending_follower] = User.get_follow_requests(locked)
  end

  test "doesn't return follow requests for deactivated accounts" do
    locked = insert(:user, is_locked: true)
    pending_follower = insert(:user, %{deactivated: true})

    CommonAPI.follow(pending_follower, locked)

    assert true == pending_follower.deactivated
    assert [] = User.get_follow_requests(locked)
  end

  test "clears follow requests when requester is blocked" do
    followed = insert(:user, is_locked: true)
    follower = insert(:user)

    CommonAPI.follow(follower, followed)
    assert [_activity] = User.get_follow_requests(followed)

    {:ok, _user_relationship} = User.block(followed, follower)
    assert [] = User.get_follow_requests(followed)
  end

  test "follow_all follows mutliple users" do
    user = insert(:user)
    followed_zero = insert(:user)
    followed_one = insert(:user)
    followed_two = insert(:user)
    blocked = insert(:user)
    not_followed = insert(:user)
    reverse_blocked = insert(:user)

    {:ok, _user_relationship} = User.block(user, blocked)
    {:ok, _user_relationship} = User.block(reverse_blocked, user)

    {:ok, user} = User.follow(user, followed_zero)

    {:ok, user} = User.follow_all(user, [followed_one, followed_two, blocked, reverse_blocked])

    assert User.following?(user, followed_one)
    assert User.following?(user, followed_two)
    assert User.following?(user, followed_zero)
    refute User.following?(user, not_followed)
    refute User.following?(user, blocked)
    refute User.following?(user, reverse_blocked)
  end

  test "follow_all follows mutliple users without duplicating" do
    user = insert(:user)
    followed_zero = insert(:user)
    followed_one = insert(:user)
    followed_two = insert(:user)

    {:ok, user} = User.follow_all(user, [followed_zero, followed_one])
    assert length(User.following(user)) == 3

    {:ok, user} = User.follow_all(user, [followed_one, followed_two])
    assert length(User.following(user)) == 4
  end

  test "follow takes a user and another user" do
    user = insert(:user)
    followed = insert(:user)

    {:ok, user} = User.follow(user, followed)

    user = User.get_cached_by_id(user.id)
    followed = User.get_cached_by_ap_id(followed.ap_id)

    assert followed.follower_count == 1
    assert user.following_count == 1

    assert User.ap_followers(followed) in User.following(user)
  end

  test "can't follow a deactivated users" do
    user = insert(:user)
    followed = insert(:user, %{deactivated: true})

    {:error, _} = User.follow(user, followed)
  end

  test "can't follow a user who blocked us" do
    blocker = insert(:user)
    blockee = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:error, _} = User.follow(blockee, blocker)
  end

  test "can't subscribe to a user who blocked us" do
    blocker = insert(:user)
    blocked = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blocked)

    {:error, _} = User.subscribe(blocked, blocker)
  end

  test "local users do not automatically follow local locked accounts" do
    follower = insert(:user, is_locked: true)
    followed = insert(:user, is_locked: true)

    {:ok, follower} = User.maybe_direct_follow(follower, followed)

    refute User.following?(follower, followed)
  end

  describe "unfollow/2" do
    setup do: clear_config([:instance, :external_user_synchronization])

    test "unfollow with syncronizes external user" do
      Pleroma.Config.put([:instance, :external_user_synchronization], true)

      followed =
        insert(:user,
          nickname: "fuser1",
          follower_address: "http://localhost:4001/users/fuser1/followers",
          following_address: "http://localhost:4001/users/fuser1/following",
          ap_id: "http://localhost:4001/users/fuser1"
        )

      user =
        insert(:user, %{
          local: false,
          nickname: "fuser2",
          ap_id: "http://localhost:4001/users/fuser2",
          follower_address: "http://localhost:4001/users/fuser2/followers",
          following_address: "http://localhost:4001/users/fuser2/following"
        })

      {:ok, user} = User.follow(user, followed, :follow_accept)

      {:ok, user, _activity} = User.unfollow(user, followed)

      user = User.get_cached_by_id(user.id)

      assert User.following(user) == []
    end

    test "unfollow takes a user and another user" do
      followed = insert(:user)
      user = insert(:user)

      {:ok, user} = User.follow(user, followed, :follow_accept)

      assert User.following(user) == [user.follower_address, followed.follower_address]

      {:ok, user, _activity} = User.unfollow(user, followed)

      assert User.following(user) == [user.follower_address]
    end

    test "unfollow doesn't unfollow yourself" do
      user = insert(:user)

      {:error, _} = User.unfollow(user, user)

      assert User.following(user) == [user.follower_address]
    end
  end

  test "test if a user is following another user" do
    followed = insert(:user)
    user = insert(:user)
    User.follow(user, followed, :follow_accept)

    assert User.following?(user, followed)
    refute User.following?(followed, user)
  end

  test "fetches correct profile for nickname beginning with number" do
    # Use old-style integer ID to try to reproduce the problem
    user = insert(:user, %{id: 1080})
    user_with_numbers = insert(:user, %{nickname: "#{user.id}garbage"})
    assert user_with_numbers == User.get_cached_by_nickname_or_id(user_with_numbers.nickname)
  end

  describe "user registration" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com"
    }

    setup do: clear_config([:instance, :autofollowed_nicknames])
    setup do: clear_config([:welcome])
    setup do: clear_config([:instance, :account_activation_required])

    test "it autofollows accounts that are set for it" do
      user = insert(:user)
      remote_user = insert(:user, %{local: false})

      Pleroma.Config.put([:instance, :autofollowed_nicknames], [
        user.nickname,
        remote_user.nickname
      ])

      cng = User.register_changeset(%User{}, @full_user_data)

      {:ok, registered_user} = User.register(cng)

      assert User.following?(registered_user, user)
      refute User.following?(registered_user, remote_user)
    end

    test "it sends a welcome message if it is set" do
      welcome_user = insert(:user)
      Pleroma.Config.put([:welcome, :direct_message, :enabled], true)
      Pleroma.Config.put([:welcome, :direct_message, :sender_nickname], welcome_user.nickname)
      Pleroma.Config.put([:welcome, :direct_message, :message], "Hello, this is a direct message")

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      activity = Repo.one(Pleroma.Activity)
      assert registered_user.ap_id in activity.recipients
      assert Object.normalize(activity).data["content"] =~ "direct message"
      assert activity.actor == welcome_user.ap_id
    end

    test "it sends a welcome chat message if it is set" do
      welcome_user = insert(:user)
      Pleroma.Config.put([:welcome, :chat_message, :enabled], true)
      Pleroma.Config.put([:welcome, :chat_message, :sender_nickname], welcome_user.nickname)
      Pleroma.Config.put([:welcome, :chat_message, :message], "Hello, this is a chat message")

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      activity = Repo.one(Pleroma.Activity)
      assert registered_user.ap_id in activity.recipients
      assert Object.normalize(activity).data["content"] =~ "chat message"
      assert activity.actor == welcome_user.ap_id
    end

    setup do:
            clear_config(:mrf_simple,
              media_removal: [],
              media_nsfw: [],
              federated_timeline_removal: [],
              report_removal: [],
              reject: [],
              followers_only: [],
              accept: [],
              avatar_removal: [],
              banner_removal: [],
              reject_deletes: []
            )

    setup do:
            clear_config(:mrf,
              policies: [
                Pleroma.Web.ActivityPub.MRF.SimplePolicy
              ]
            )

    test "it sends a welcome chat message when Simple policy applied to local instance" do
      Pleroma.Config.put([:mrf_simple, :media_nsfw], ["localhost"])

      welcome_user = insert(:user)
      Pleroma.Config.put([:welcome, :chat_message, :enabled], true)
      Pleroma.Config.put([:welcome, :chat_message, :sender_nickname], welcome_user.nickname)
      Pleroma.Config.put([:welcome, :chat_message, :message], "Hello, this is a chat message")

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      activity = Repo.one(Pleroma.Activity)
      assert registered_user.ap_id in activity.recipients
      assert Object.normalize(activity).data["content"] =~ "chat message"
      assert activity.actor == welcome_user.ap_id
    end

    test "it sends a welcome email message if it is set" do
      welcome_user = insert(:user)
      Pleroma.Config.put([:welcome, :email, :enabled], true)
      Pleroma.Config.put([:welcome, :email, :sender], welcome_user.email)

      Pleroma.Config.put(
        [:welcome, :email, :subject],
        "Hello, welcome to cool site: <%= instance_name %>"
      )

      instance_name = Pleroma.Config.get([:instance, :name])

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      assert_email_sent(
        from: {instance_name, welcome_user.email},
        to: {registered_user.name, registered_user.email},
        subject: "Hello, welcome to cool site: #{instance_name}",
        html_body: "Welcome to #{instance_name}"
      )
    end

    test "it sends a confirm email" do
      Pleroma.Config.put([:instance, :account_activation_required], true)

      cng = User.register_changeset(%User{}, @full_user_data)
      {:ok, registered_user} = User.register(cng)
      ObanHelpers.perform_all()

      Pleroma.Emails.UserEmail.account_confirmation_email(registered_user)
      # temporary hackney fix until hackney max_connections bug is fixed
      # https://git.pleroma.social/pleroma/pleroma/-/issues/2101
      |> Swoosh.Email.put_private(:hackney_options, ssl_options: [versions: [:"tlsv1.2"]])
      |> assert_email_sent()
    end

    test "it requires an email, name, nickname and password, bio is optional when account_activation_required is enabled" do
      Pleroma.Config.put([:instance, :account_activation_required], true)

      @full_user_data
      |> Map.keys()
      |> Enum.each(fn key ->
        params = Map.delete(@full_user_data, key)
        changeset = User.register_changeset(%User{}, params)

        assert if key == :bio, do: changeset.valid?, else: not changeset.valid?
      end)
    end

    test "it requires an name, nickname and password, bio and email are optional when account_activation_required is disabled" do
      Pleroma.Config.put([:instance, :account_activation_required], false)

      @full_user_data
      |> Map.keys()
      |> Enum.each(fn key ->
        params = Map.delete(@full_user_data, key)
        changeset = User.register_changeset(%User{}, params)

        assert if key in [:bio, :email], do: changeset.valid?, else: not changeset.valid?
      end)
    end

    test "it restricts certain nicknames" do
      [restricted_name | _] = Pleroma.Config.get([User, :restricted_nicknames])

      assert is_bitstring(restricted_name)

      params =
        @full_user_data
        |> Map.put(:nickname, restricted_name)

      changeset = User.register_changeset(%User{}, params)

      refute changeset.valid?
    end

    test "it blocks blacklisted email domains" do
      clear_config([User, :email_blacklist], ["trolling.world"])

      # Block with match
      params = Map.put(@full_user_data, :email, "troll@trolling.world")
      changeset = User.register_changeset(%User{}, params)
      refute changeset.valid?

      # Block with subdomain match
      params = Map.put(@full_user_data, :email, "troll@gnomes.trolling.world")
      changeset = User.register_changeset(%User{}, params)
      refute changeset.valid?

      # Pass with different domains that are similar
      params = Map.put(@full_user_data, :email, "troll@gnomestrolling.world")
      changeset = User.register_changeset(%User{}, params)
      assert changeset.valid?

      params = Map.put(@full_user_data, :email, "troll@trolling.world.us")
      changeset = User.register_changeset(%User{}, params)
      assert changeset.valid?
    end

    test "it sets the password_hash and ap_id" do
      changeset = User.register_changeset(%User{}, @full_user_data)

      assert changeset.valid?

      assert is_binary(changeset.changes[:password_hash])
      assert changeset.changes[:ap_id] == User.ap_id(%User{nickname: @full_user_data.nickname})

      assert changeset.changes.follower_address == "#{changeset.changes.ap_id}/followers"
    end

    test "it sets the 'accepts_chat_messages' set to true" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      assert user.accepts_chat_messages
    end

    test "it creates a confirmed user" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      refute user.confirmation_pending
    end
  end

  describe "user registration, with :account_activation_required" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com"
    }
    setup do: clear_config([:instance, :account_activation_required], true)

    test "it creates unconfirmed user" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      assert user.confirmation_pending
      assert user.confirmation_token
    end

    test "it creates confirmed user if :confirmed option is given" do
      changeset = User.register_changeset(%User{}, @full_user_data, need_confirmation: false)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      refute user.confirmation_pending
      refute user.confirmation_token
    end
  end

  describe "user registration, with :account_approval_required" do
    @full_user_data %{
      bio: "A guy",
      name: "my name",
      nickname: "nick",
      password: "test",
      password_confirmation: "test",
      email: "email@example.com",
      registration_reason: "I'm a cool guy :)"
    }
    setup do: clear_config([:instance, :account_approval_required], true)

    test "it creates unapproved user" do
      changeset = User.register_changeset(%User{}, @full_user_data)
      assert changeset.valid?

      {:ok, user} = Repo.insert(changeset)

      assert user.approval_pending
      assert user.registration_reason == "I'm a cool guy :)"
    end

    test "it restricts length of registration reason" do
      reason_limit = Pleroma.Config.get([:instance, :registration_reason_length])

      assert is_integer(reason_limit)

      params =
        @full_user_data
        |> Map.put(
          :registration_reason,
          "Quia et nesciunt dolores numquam ipsam nisi sapiente soluta. Ullam repudiandae nisi quam porro officiis officiis ad. Consequatur animi velit ex quia. Odit voluptatem perferendis quia ut nisi. Dignissimos sit soluta atque aliquid dolorem ut dolorum ut. Labore voluptates iste iusto amet voluptatum earum. Ad fugit illum nam eos ut nemo. Pariatur ea fuga non aspernatur. Dignissimos debitis officia corporis est nisi ab et. Atque itaque alias eius voluptas minus. Accusamus numquam tempore occaecati in."
        )

      changeset = User.register_changeset(%User{}, params)

      refute changeset.valid?
    end
  end

  describe "get_or_fetch/1" do
    test "gets an existing user by nickname" do
      user = insert(:user)
      {:ok, fetched_user} = User.get_or_fetch(user.nickname)

      assert user == fetched_user
    end

    test "gets an existing user by ap_id" do
      ap_id = "http://mastodon.example.org/users/admin"

      user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: ap_id
        )

      {:ok, fetched_user} = User.get_or_fetch(ap_id)
      freshed_user = refresh_record(user)
      assert freshed_user == fetched_user
    end
  end

  describe "fetching a user from nickname or trying to build one" do
    test "gets an existing user" do
      user = insert(:user)
      {:ok, fetched_user} = User.get_or_fetch_by_nickname(user.nickname)

      assert user == fetched_user
    end

    test "gets an existing user, case insensitive" do
      user = insert(:user, nickname: "nick")
      {:ok, fetched_user} = User.get_or_fetch_by_nickname("NICK")

      assert user == fetched_user
    end

    test "gets an existing user by fully qualified nickname" do
      user = insert(:user)

      {:ok, fetched_user} =
        User.get_or_fetch_by_nickname(user.nickname <> "@" <> Pleroma.Web.Endpoint.host())

      assert user == fetched_user
    end

    test "gets an existing user by fully qualified nickname, case insensitive" do
      user = insert(:user, nickname: "nick")
      casing_altered_fqn = String.upcase(user.nickname <> "@" <> Pleroma.Web.Endpoint.host())

      {:ok, fetched_user} = User.get_or_fetch_by_nickname(casing_altered_fqn)

      assert user == fetched_user
    end

    @tag capture_log: true
    test "returns nil if no user could be fetched" do
      {:error, fetched_user} = User.get_or_fetch_by_nickname("nonexistant@social.heldscal.la")
      assert fetched_user == "not found nonexistant@social.heldscal.la"
    end

    test "returns nil for nonexistant local user" do
      {:error, fetched_user} = User.get_or_fetch_by_nickname("nonexistant")
      assert fetched_user == "not found nonexistant"
    end

    test "updates an existing user, if stale" do
      a_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -604_800)

      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/admin",
          last_refreshed_at: a_week_ago
        )

      assert orig_user.last_refreshed_at == a_week_ago

      {:ok, user} = User.get_or_fetch_by_ap_id("http://mastodon.example.org/users/admin")

      assert user.inbox

      refute user.last_refreshed_at == orig_user.last_refreshed_at
    end

    test "if nicknames clash, the old user gets a prefix with the old id to the nickname" do
      a_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -604_800)

      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/harinezumigari",
          last_refreshed_at: a_week_ago
        )

      assert orig_user.last_refreshed_at == a_week_ago

      {:ok, user} = User.get_or_fetch_by_ap_id("http://mastodon.example.org/users/admin")

      assert user.inbox

      refute user.id == orig_user.id

      orig_user = User.get_by_id(orig_user.id)

      assert orig_user.nickname == "#{orig_user.id}.admin@mastodon.example.org"
    end

    @tag capture_log: true
    test "it returns the old user if stale, but unfetchable" do
      a_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -604_800)

      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/raymoo",
          last_refreshed_at: a_week_ago
        )

      assert orig_user.last_refreshed_at == a_week_ago

      {:ok, user} = User.get_or_fetch_by_ap_id("http://mastodon.example.org/users/raymoo")

      assert user.last_refreshed_at == orig_user.last_refreshed_at
    end
  end

  test "returns an ap_id for a user" do
    user = insert(:user)

    assert User.ap_id(user) ==
             Pleroma.Web.Router.Helpers.user_feed_url(
               Pleroma.Web.Endpoint,
               :feed_redirect,
               user.nickname
             )
  end

  test "returns an ap_followers link for a user" do
    user = insert(:user)

    assert User.ap_followers(user) ==
             Pleroma.Web.Router.Helpers.user_feed_url(
               Pleroma.Web.Endpoint,
               :feed_redirect,
               user.nickname
             ) <> "/followers"
  end

  describe "remote user changeset" do
    @valid_remote %{
      bio: "hello",
      name: "Someone",
      nickname: "a@b.de",
      ap_id: "http...",
      avatar: %{some: "avatar"}
    }
    setup do: clear_config([:instance, :user_bio_length])
    setup do: clear_config([:instance, :user_name_length])

    test "it confirms validity" do
      cs = User.remote_user_changeset(@valid_remote)
      assert cs.valid?
    end

    test "it sets the follower_adress" do
      cs = User.remote_user_changeset(@valid_remote)
      # remote users get a fake local follower address
      assert cs.changes.follower_address ==
               User.ap_followers(%User{nickname: @valid_remote[:nickname]})
    end

    test "it enforces the fqn format for nicknames" do
      cs = User.remote_user_changeset(%{@valid_remote | nickname: "bla"})
      assert Ecto.Changeset.get_field(cs, :local) == false
      assert cs.changes.avatar
      refute cs.valid?
    end

    test "it has required fields" do
      [:ap_id]
      |> Enum.each(fn field ->
        cs = User.remote_user_changeset(Map.delete(@valid_remote, field))
        refute cs.valid?
      end)
    end

    test "it is invalid given a local user" do
      user = insert(:user)
      cs = User.remote_user_changeset(user, %{name: "tom from myspace"})

      refute cs.valid?
    end
  end

  describe "followers and friends" do
    test "gets all followers for a given user" do
      user = insert(:user)
      follower_one = insert(:user)
      follower_two = insert(:user)
      not_follower = insert(:user)

      {:ok, follower_one} = User.follow(follower_one, user)
      {:ok, follower_two} = User.follow(follower_two, user)

      res = User.get_followers(user)

      assert Enum.member?(res, follower_one)
      assert Enum.member?(res, follower_two)
      refute Enum.member?(res, not_follower)
    end

    test "gets all friends (followed users) for a given user" do
      user = insert(:user)
      followed_one = insert(:user)
      followed_two = insert(:user)
      not_followed = insert(:user)

      {:ok, user} = User.follow(user, followed_one)
      {:ok, user} = User.follow(user, followed_two)

      res = User.get_friends(user)

      followed_one = User.get_cached_by_ap_id(followed_one.ap_id)
      followed_two = User.get_cached_by_ap_id(followed_two.ap_id)
      assert Enum.member?(res, followed_one)
      assert Enum.member?(res, followed_two)
      refute Enum.member?(res, not_followed)
    end
  end

  describe "updating note and follower count" do
    test "it sets the note_count property" do
      note = insert(:note)

      user = User.get_cached_by_ap_id(note.data["actor"])

      assert user.note_count == 0

      {:ok, user} = User.update_note_count(user)

      assert user.note_count == 1
    end

    test "it increases the note_count property" do
      note = insert(:note)
      user = User.get_cached_by_ap_id(note.data["actor"])

      assert user.note_count == 0

      {:ok, user} = User.increase_note_count(user)

      assert user.note_count == 1

      {:ok, user} = User.increase_note_count(user)

      assert user.note_count == 2
    end

    test "it decreases the note_count property" do
      note = insert(:note)
      user = User.get_cached_by_ap_id(note.data["actor"])

      assert user.note_count == 0

      {:ok, user} = User.increase_note_count(user)

      assert user.note_count == 1

      {:ok, user} = User.decrease_note_count(user)

      assert user.note_count == 0

      {:ok, user} = User.decrease_note_count(user)

      assert user.note_count == 0
    end

    test "it sets the follower_count property" do
      user = insert(:user)
      follower = insert(:user)

      User.follow(follower, user)

      assert user.follower_count == 0

      {:ok, user} = User.update_follower_count(user)

      assert user.follower_count == 1
    end
  end

  describe "mutes" do
    test "it mutes people" do
      user = insert(:user)
      muted_user = insert(:user)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)

      {:ok, _user_relationships} = User.mute(user, muted_user)

      assert User.mutes?(user, muted_user)
      assert User.muted_notifications?(user, muted_user)
    end

    test "it unmutes users" do
      user = insert(:user)
      muted_user = insert(:user)

      {:ok, _user_relationships} = User.mute(user, muted_user)
      {:ok, _user_mute} = User.unmute(user, muted_user)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)
    end

    test "it mutes user without notifications" do
      user = insert(:user)
      muted_user = insert(:user)

      refute User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)

      {:ok, _user_relationships} = User.mute(user, muted_user, false)

      assert User.mutes?(user, muted_user)
      refute User.muted_notifications?(user, muted_user)
    end
  end

  describe "blocks" do
    test "it blocks people" do
      user = insert(:user)
      blocked_user = insert(:user)

      refute User.blocks?(user, blocked_user)

      {:ok, _user_relationship} = User.block(user, blocked_user)

      assert User.blocks?(user, blocked_user)
    end

    test "it unblocks users" do
      user = insert(:user)
      blocked_user = insert(:user)

      {:ok, _user_relationship} = User.block(user, blocked_user)
      {:ok, _user_block} = User.unblock(user, blocked_user)

      refute User.blocks?(user, blocked_user)
    end

    test "blocks tear down cyclical follow relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, blocker} = User.follow(blocker, blocked)
      {:ok, blocked} = User.follow(blocked, blocker)

      assert User.following?(blocker, blocked)
      assert User.following?(blocked, blocker)

      {:ok, _user_relationship} = User.block(blocker, blocked)
      blocked = User.get_cached_by_id(blocked.id)

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "blocks tear down blocker->blocked follow relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, blocker} = User.follow(blocker, blocked)

      assert User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)

      {:ok, _user_relationship} = User.block(blocker, blocked)
      blocked = User.get_cached_by_id(blocked.id)

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "blocks tear down blocked->blocker follow relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, blocked} = User.follow(blocked, blocker)

      refute User.following?(blocker, blocked)
      assert User.following?(blocked, blocker)

      {:ok, _user_relationship} = User.block(blocker, blocked)
      blocked = User.get_cached_by_id(blocked.id)

      assert User.blocks?(blocker, blocked)

      refute User.following?(blocker, blocked)
      refute User.following?(blocked, blocker)
    end

    test "blocks tear down blocked->blocker subscription relationships" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, _subscription} = User.subscribe(blocked, blocker)

      assert User.subscribed_to?(blocked, blocker)
      refute User.subscribed_to?(blocker, blocked)

      {:ok, _user_relationship} = User.block(blocker, blocked)

      assert User.blocks?(blocker, blocked)
      refute User.subscribed_to?(blocker, blocked)
      refute User.subscribed_to?(blocked, blocker)
    end
  end

  describe "domain blocking" do
    test "blocks domains" do
      user = insert(:user)
      collateral_user = insert(:user, %{ap_id: "https://awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "awful-and-rude-instance.com")

      assert User.blocks?(user, collateral_user)
    end

    test "does not block domain with same end" do
      user = insert(:user)

      collateral_user =
        insert(:user, %{ap_id: "https://another-awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "awful-and-rude-instance.com")

      refute User.blocks?(user, collateral_user)
    end

    test "does not block domain with same end if wildcard added" do
      user = insert(:user)

      collateral_user =
        insert(:user, %{ap_id: "https://another-awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "*.awful-and-rude-instance.com")

      refute User.blocks?(user, collateral_user)
    end

    test "blocks domain with wildcard for subdomain" do
      user = insert(:user)

      user_from_subdomain =
        insert(:user, %{ap_id: "https://subdomain.awful-and-rude-instance.com/user/bully"})

      user_with_two_subdomains =
        insert(:user, %{
          ap_id: "https://subdomain.second_subdomain.awful-and-rude-instance.com/user/bully"
        })

      user_domain = insert(:user, %{ap_id: "https://awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "*.awful-and-rude-instance.com")

      assert User.blocks?(user, user_from_subdomain)
      assert User.blocks?(user, user_with_two_subdomains)
      assert User.blocks?(user, user_domain)
    end

    test "unblocks domains" do
      user = insert(:user)
      collateral_user = insert(:user, %{ap_id: "https://awful-and-rude-instance.com/user/bully"})

      {:ok, user} = User.block_domain(user, "awful-and-rude-instance.com")
      {:ok, user} = User.unblock_domain(user, "awful-and-rude-instance.com")

      refute User.blocks?(user, collateral_user)
    end

    test "follows take precedence over domain blocks" do
      user = insert(:user)
      good_eggo = insert(:user, %{ap_id: "https://meanies.social/user/cuteposter"})

      {:ok, user} = User.block_domain(user, "meanies.social")
      {:ok, user} = User.follow(user, good_eggo)

      refute User.blocks?(user, good_eggo)
    end
  end

  describe "get_recipients_from_activity" do
    test "works for announces" do
      actor = insert(:user)
      user = insert(:user, local: true)

      {:ok, activity} = CommonAPI.post(actor, %{status: "hello"})
      {:ok, announce} = CommonAPI.repeat(activity.id, user)

      recipients = User.get_recipients_from_activity(announce)

      assert user in recipients
    end

    test "get recipients" do
      actor = insert(:user)
      user = insert(:user, local: true)
      user_two = insert(:user, local: false)
      addressed = insert(:user, local: true)
      addressed_remote = insert(:user, local: false)

      {:ok, activity} =
        CommonAPI.post(actor, %{
          status: "hey @#{addressed.nickname} @#{addressed_remote.nickname}"
        })

      assert Enum.map([actor, addressed], & &1.ap_id) --
               Enum.map(User.get_recipients_from_activity(activity), & &1.ap_id) == []

      {:ok, user} = User.follow(user, actor)
      {:ok, _user_two} = User.follow(user_two, actor)
      recipients = User.get_recipients_from_activity(activity)
      assert length(recipients) == 3
      assert user in recipients
      assert addressed in recipients
    end

    test "has following" do
      actor = insert(:user)
      user = insert(:user)
      user_two = insert(:user)
      addressed = insert(:user, local: true)

      {:ok, activity} =
        CommonAPI.post(actor, %{
          status: "hey @#{addressed.nickname}"
        })

      assert Enum.map([actor, addressed], & &1.ap_id) --
               Enum.map(User.get_recipients_from_activity(activity), & &1.ap_id) == []

      {:ok, _actor} = User.follow(actor, user)
      {:ok, _actor} = User.follow(actor, user_two)
      recipients = User.get_recipients_from_activity(activity)
      assert length(recipients) == 2
      assert addressed in recipients
    end
  end

  describe ".deactivate" do
    test "can de-activate then re-activate a user" do
      user = insert(:user)
      assert false == user.deactivated
      {:ok, user} = User.deactivate(user)
      assert true == user.deactivated
      {:ok, user} = User.deactivate(user, false)
      assert false == user.deactivated
    end

    test "hide a user from followers" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, user} = User.follow(user, user2)
      {:ok, _user} = User.deactivate(user)

      user2 = User.get_cached_by_id(user2.id)

      assert user2.follower_count == 0
      assert [] = User.get_followers(user2)
    end

    test "hide a user from friends" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, user2} = User.follow(user2, user)
      assert user2.following_count == 1
      assert User.following_count(user2) == 1

      {:ok, _user} = User.deactivate(user)

      user2 = User.get_cached_by_id(user2.id)

      assert refresh_record(user2).following_count == 0
      assert user2.following_count == 0
      assert User.following_count(user2) == 0
      assert [] = User.get_friends(user2)
    end

    test "hide a user's statuses from timelines and notifications" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, user2} = User.follow(user2, user)

      {:ok, activity} = CommonAPI.post(user, %{status: "hey @#{user2.nickname}"})

      activity = Repo.preload(activity, :bookmark)

      [notification] = Pleroma.Notification.for_user(user2)
      assert notification.activity.id == activity.id

      assert [activity] == ActivityPub.fetch_public_activities(%{}) |> Repo.preload(:bookmark)

      assert [%{activity | thread_muted?: CommonAPI.thread_muted?(user2, activity)}] ==
               ActivityPub.fetch_activities([user2.ap_id | User.following(user2)], %{
                 user: user2
               })

      {:ok, _user} = User.deactivate(user)

      assert [] == ActivityPub.fetch_public_activities(%{})
      assert [] == Pleroma.Notification.for_user(user2)

      assert [] ==
               ActivityPub.fetch_activities([user2.ap_id | User.following(user2)], %{
                 user: user2
               })
    end
  end

  describe "approve" do
    test "approves a user" do
      user = insert(:user, approval_pending: true)
      assert true == user.approval_pending
      {:ok, user} = User.approve(user)
      assert false == user.approval_pending
    end

    test "approves a list of users" do
      unapproved_users = [
        insert(:user, approval_pending: true),
        insert(:user, approval_pending: true),
        insert(:user, approval_pending: true)
      ]

      {:ok, users} = User.approve(unapproved_users)

      assert Enum.count(users) == 3

      Enum.each(users, fn user ->
        assert false == user.approval_pending
      end)
    end
  end

  describe "delete" do
    setup do
      {:ok, user} = insert(:user) |> User.set_cache()

      [user: user]
    end

    setup do: clear_config([:instance, :federating])

    test ".delete_user_activities deletes all create activities", %{user: user} do
      {:ok, activity} = CommonAPI.post(user, %{status: "2hu"})

      User.delete_user_activities(user)

      # TODO: Test removal favorites, repeats, delete activities.
      refute Activity.get_by_id(activity.id)
    end

    test "it deactivates a user, all follow relationships and all activities", %{user: user} do
      follower = insert(:user)
      {:ok, follower} = User.follow(follower, user)

      locked_user = insert(:user, name: "locked", is_locked: true)
      {:ok, _} = User.follow(user, locked_user, :follow_pending)

      object = insert(:note, user: user)
      activity = insert(:note_activity, user: user, note: object)

      object_two = insert(:note, user: follower)
      activity_two = insert(:note_activity, user: follower, note: object_two)

      {:ok, like} = CommonAPI.favorite(user, activity_two.id)
      {:ok, like_two} = CommonAPI.favorite(follower, activity.id)
      {:ok, repeat} = CommonAPI.repeat(activity_two.id, user)

      {:ok, job} = User.delete(user)
      {:ok, _user} = ObanHelpers.perform(job)

      follower = User.get_cached_by_id(follower.id)

      refute User.following?(follower, user)
      assert %{deactivated: true} = User.get_by_id(user.id)

      assert [] == User.get_follow_requests(locked_user)

      user_activities =
        user.ap_id
        |> Activity.Queries.by_actor()
        |> Repo.all()
        |> Enum.map(fn act -> act.data["type"] end)

      assert Enum.all?(user_activities, fn act -> act in ~w(Delete Undo) end)

      refute Activity.get_by_id(activity.id)
      refute Activity.get_by_id(like.id)
      refute Activity.get_by_id(like_two.id)
      refute Activity.get_by_id(repeat.id)
    end
  end

  describe "delete/1 when confirmation is pending" do
    setup do
      user = insert(:user, confirmation_pending: true)
      {:ok, user: user}
    end

    test "deletes user from database when activation required", %{user: user} do
      clear_config([:instance, :account_activation_required], true)

      {:ok, job} = User.delete(user)
      {:ok, _} = ObanHelpers.perform(job)

      refute User.get_cached_by_id(user.id)
      refute User.get_by_id(user.id)
    end

    test "deactivates user when activation is not required", %{user: user} do
      clear_config([:instance, :account_activation_required], false)

      {:ok, job} = User.delete(user)
      {:ok, _} = ObanHelpers.perform(job)

      assert %{deactivated: true} = User.get_cached_by_id(user.id)
      assert %{deactivated: true} = User.get_by_id(user.id)
    end
  end

  test "delete/1 when approval is pending deletes the user" do
    user = insert(:user, approval_pending: true)

    {:ok, job} = User.delete(user)
    {:ok, _} = ObanHelpers.perform(job)

    refute User.get_cached_by_id(user.id)
    refute User.get_by_id(user.id)
  end

  test "delete/1 purges a user when they wouldn't be fully deleted" do
    user =
      insert(:user, %{
        bio: "eyy lmao",
        name: "qqqqqqq",
        password_hash: "pdfk2$1b3n159001",
        keys: "RSA begin buplic key",
        public_key: "--PRIVATE KEYE--",
        avatar: %{"a" => "b"},
        tags: ["qqqqq"],
        banner: %{"a" => "b"},
        background: %{"a" => "b"},
        note_count: 9,
        follower_count: 9,
        following_count: 9001,
        is_locked: true,
        confirmation_pending: true,
        password_reset_pending: true,
        approval_pending: true,
        registration_reason: "ahhhhh",
        confirmation_token: "qqqq",
        domain_blocks: ["lain.com"],
        deactivated: true,
        ap_enabled: true,
        is_moderator: true,
        is_admin: true,
        mastofe_settings: %{"a" => "b"},
        mascot: %{"a" => "b"},
        emoji: %{"a" => "b"},
        pleroma_settings_store: %{"q" => "x"},
        fields: [%{"gg" => "qq"}],
        raw_fields: [%{"gg" => "qq"}],
        discoverable: true,
        also_known_as: ["https://lol.olo/users/loll"]
      })

    {:ok, job} = User.delete(user)
    {:ok, _} = ObanHelpers.perform(job)
    user = User.get_by_id(user.id)

    assert %User{
             bio: "",
             raw_bio: nil,
             email: nil,
             name: nil,
             password_hash: nil,
             keys: nil,
             public_key: nil,
             avatar: %{},
             tags: [],
             last_refreshed_at: nil,
             last_digest_emailed_at: nil,
             banner: %{},
             background: %{},
             note_count: 0,
             follower_count: 0,
             following_count: 0,
             is_locked: false,
             confirmation_pending: false,
             password_reset_pending: false,
             approval_pending: false,
             registration_reason: nil,
             confirmation_token: nil,
             domain_blocks: [],
             deactivated: true,
             ap_enabled: false,
             is_moderator: false,
             is_admin: false,
             mastofe_settings: nil,
             mascot: nil,
             emoji: %{},
             pleroma_settings_store: %{},
             fields: [],
             raw_fields: [],
             discoverable: false,
             also_known_as: []
           } = user
  end

  test "get_public_key_for_ap_id fetches a user that's not in the db" do
    assert {:ok, _key} = User.get_public_key_for_ap_id("http://mastodon.example.org/users/admin")
  end

  describe "per-user rich-text filtering" do
    test "html_filter_policy returns default policies, when rich-text is enabled" do
      user = insert(:user)

      assert Pleroma.Config.get([:markup, :scrub_policy]) == User.html_filter_policy(user)
    end

    test "html_filter_policy returns TwitterText scrubber when rich-text is disabled" do
      user = insert(:user, no_rich_text: true)

      assert Pleroma.HTML.Scrubber.TwitterText == User.html_filter_policy(user)
    end
  end

  describe "caching" do
    test "invalidate_cache works" do
      user = insert(:user)

      User.set_cache(user)
      User.invalidate_cache(user)

      {:ok, nil} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")
      {:ok, nil} = Cachex.get(:user_cache, "nickname:#{user.nickname}")
    end

    test "User.delete() plugs any possible zombie objects" do
      user = insert(:user)

      {:ok, job} = User.delete(user)
      {:ok, _} = ObanHelpers.perform(job)

      {:ok, cached_user} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")

      assert cached_user != user

      {:ok, cached_user} = Cachex.get(:user_cache, "nickname:#{user.ap_id}")

      assert cached_user != user
    end
  end

  describe "account_status/1" do
    setup do: clear_config([:instance, :account_activation_required])

    test "return confirmation_pending for unconfirm user" do
      Pleroma.Config.put([:instance, :account_activation_required], true)
      user = insert(:user, confirmation_pending: true)
      assert User.account_status(user) == :confirmation_pending
    end

    test "return active for confirmed user" do
      Pleroma.Config.put([:instance, :account_activation_required], true)
      user = insert(:user, confirmation_pending: false)
      assert User.account_status(user) == :active
    end

    test "return active for remote user" do
      user = insert(:user, local: false)
      assert User.account_status(user) == :active
    end

    test "returns :password_reset_pending for user with reset password" do
      user = insert(:user, password_reset_pending: true)
      assert User.account_status(user) == :password_reset_pending
    end

    test "returns :deactivated for deactivated user" do
      user = insert(:user, local: true, confirmation_pending: false, deactivated: true)
      assert User.account_status(user) == :deactivated
    end

    test "returns :approval_pending for unapproved user" do
      user = insert(:user, local: true, approval_pending: true)
      assert User.account_status(user) == :approval_pending

      user = insert(:user, local: true, confirmation_pending: true, approval_pending: true)
      assert User.account_status(user) == :approval_pending
    end
  end

  describe "superuser?/1" do
    test "returns false for unprivileged users" do
      user = insert(:user, local: true)

      refute User.superuser?(user)
    end

    test "returns false for remote users" do
      user = insert(:user, local: false)
      remote_admin_user = insert(:user, local: false, is_admin: true)

      refute User.superuser?(user)
      refute User.superuser?(remote_admin_user)
    end

    test "returns true for local moderators" do
      user = insert(:user, local: true, is_moderator: true)

      assert User.superuser?(user)
    end

    test "returns true for local admins" do
      user = insert(:user, local: true, is_admin: true)

      assert User.superuser?(user)
    end
  end

  describe "invisible?/1" do
    test "returns true for an invisible user" do
      user = insert(:user, local: true, invisible: true)

      assert User.invisible?(user)
    end

    test "returns false for a non-invisible user" do
      user = insert(:user, local: true)

      refute User.invisible?(user)
    end
  end

  describe "visible_for/2" do
    test "returns true when the account is itself" do
      user = insert(:user, local: true)

      assert User.visible_for(user, user) == :visible
    end

    test "returns false when the account is unconfirmed and confirmation is required" do
      Pleroma.Config.put([:instance, :account_activation_required], true)

      user = insert(:user, local: true, confirmation_pending: true)
      other_user = insert(:user, local: true)

      refute User.visible_for(user, other_user) == :visible
    end

    test "returns true when the account is unconfirmed and confirmation is required but the account is remote" do
      Pleroma.Config.put([:instance, :account_activation_required], true)

      user = insert(:user, local: false, confirmation_pending: true)
      other_user = insert(:user, local: true)

      assert User.visible_for(user, other_user) == :visible
    end

    test "returns true when the account is unconfirmed and confirmation is not required" do
      user = insert(:user, local: true, confirmation_pending: true)
      other_user = insert(:user, local: true)

      assert User.visible_for(user, other_user) == :visible
    end

    test "returns true when the account is unconfirmed and being viewed by a privileged account (confirmation required)" do
      Pleroma.Config.put([:instance, :account_activation_required], true)

      user = insert(:user, local: true, confirmation_pending: true)
      other_user = insert(:user, local: true, is_admin: true)

      assert User.visible_for(user, other_user) == :visible
    end
  end

  describe "parse_bio/2" do
    test "preserves hosts in user links text" do
      remote_user = insert(:user, local: false, nickname: "nick@domain.com")
      user = insert(:user)
      bio = "A.k.a. @nick@domain.com"

      expected_text =
        ~s(A.k.a. <span class="h-card"><a class="u-url mention" data-user="#{remote_user.id}" href="#{
          remote_user.ap_id
        }" rel="ugc">@<span>nick@domain.com</span></a></span>)

      assert expected_text == User.parse_bio(bio, user)
    end

    test "Adds rel=me on linkbacked urls" do
      user = insert(:user, ap_id: "https://social.example.org/users/lain")

      bio = "http://example.com/rel_me/null"
      expected_text = "<a href=\"#{bio}\">#{bio}</a>"
      assert expected_text == User.parse_bio(bio, user)

      bio = "http://example.com/rel_me/link"
      expected_text = "<a href=\"#{bio}\" rel=\"me\">#{bio}</a>"
      assert expected_text == User.parse_bio(bio, user)

      bio = "http://example.com/rel_me/anchor"
      expected_text = "<a href=\"#{bio}\" rel=\"me\">#{bio}</a>"
      assert expected_text == User.parse_bio(bio, user)
    end
  end

  test "follower count is updated when a follower is blocked" do
    user = insert(:user)
    follower = insert(:user)
    follower2 = insert(:user)
    follower3 = insert(:user)

    {:ok, follower} = User.follow(follower, user)
    {:ok, _follower2} = User.follow(follower2, user)
    {:ok, _follower3} = User.follow(follower3, user)

    {:ok, _user_relationship} = User.block(user, follower)
    user = refresh_record(user)

    assert user.follower_count == 2
  end

  describe "list_inactive_users_query/1" do
    defp days_ago(days) do
      NaiveDateTime.add(
        NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
        -days * 60 * 60 * 24,
        :second
      )
    end

    test "Users are inactive by default" do
      total = 10

      users =
        Enum.map(1..total, fn _ ->
          insert(:user, last_digest_emailed_at: days_ago(20), deactivated: false)
        end)

      inactive_users_ids =
        Pleroma.User.list_inactive_users_query()
        |> Pleroma.Repo.all()
        |> Enum.map(& &1.id)

      Enum.each(users, fn user ->
        assert user.id in inactive_users_ids
      end)
    end

    test "Only includes users who has no recent activity" do
      total = 10

      users =
        Enum.map(1..total, fn _ ->
          insert(:user, last_digest_emailed_at: days_ago(20), deactivated: false)
        end)

      {inactive, active} = Enum.split(users, trunc(total / 2))

      Enum.map(active, fn user ->
        to = Enum.random(users -- [user])

        {:ok, _} =
          CommonAPI.post(user, %{
            status: "hey @#{to.nickname}"
          })
      end)

      inactive_users_ids =
        Pleroma.User.list_inactive_users_query()
        |> Pleroma.Repo.all()
        |> Enum.map(& &1.id)

      Enum.each(active, fn user ->
        refute user.id in inactive_users_ids
      end)

      Enum.each(inactive, fn user ->
        assert user.id in inactive_users_ids
      end)
    end

    test "Only includes users with no read notifications" do
      total = 10

      users =
        Enum.map(1..total, fn _ ->
          insert(:user, last_digest_emailed_at: days_ago(20), deactivated: false)
        end)

      [sender | recipients] = users
      {inactive, active} = Enum.split(recipients, trunc(total / 2))

      Enum.each(recipients, fn to ->
        {:ok, _} =
          CommonAPI.post(sender, %{
            status: "hey @#{to.nickname}"
          })

        {:ok, _} =
          CommonAPI.post(sender, %{
            status: "hey again @#{to.nickname}"
          })
      end)

      Enum.each(active, fn user ->
        [n1, _n2] = Pleroma.Notification.for_user(user)
        {:ok, _} = Pleroma.Notification.read_one(user, n1.id)
      end)

      inactive_users_ids =
        Pleroma.User.list_inactive_users_query()
        |> Pleroma.Repo.all()
        |> Enum.map(& &1.id)

      Enum.each(active, fn user ->
        refute user.id in inactive_users_ids
      end)

      Enum.each(inactive, fn user ->
        assert user.id in inactive_users_ids
      end)
    end
  end

  describe "toggle_confirmation/1" do
    test "if user is confirmed" do
      user = insert(:user, confirmation_pending: false)
      {:ok, user} = User.toggle_confirmation(user)

      assert user.confirmation_pending
      assert user.confirmation_token
    end

    test "if user is unconfirmed" do
      user = insert(:user, confirmation_pending: true, confirmation_token: "some token")
      {:ok, user} = User.toggle_confirmation(user)

      refute user.confirmation_pending
      refute user.confirmation_token
    end
  end

  describe "ensure_keys_present" do
    test "it creates keys for a user and stores them in info" do
      user = insert(:user)
      refute is_binary(user.keys)
      {:ok, user} = User.ensure_keys_present(user)
      assert is_binary(user.keys)
    end

    test "it doesn't create keys if there already are some" do
      user = insert(:user, keys: "xxx")
      {:ok, user} = User.ensure_keys_present(user)
      assert user.keys == "xxx"
    end
  end

  describe "get_ap_ids_by_nicknames" do
    test "it returns a list of AP ids for a given set of nicknames" do
      user = insert(:user)
      user_two = insert(:user)

      ap_ids = User.get_ap_ids_by_nicknames([user.nickname, user_two.nickname, "nonexistent"])
      assert length(ap_ids) == 2
      assert user.ap_id in ap_ids
      assert user_two.ap_id in ap_ids
    end
  end

  describe "sync followers count" do
    setup do
      user1 = insert(:user, local: false, ap_id: "http://localhost:4001/users/masto_closed")
      user2 = insert(:user, local: false, ap_id: "http://localhost:4001/users/fuser2")
      insert(:user, local: true)
      insert(:user, local: false, deactivated: true)
      {:ok, user1: user1, user2: user2}
    end

    test "external_users/1 external active users with limit", %{user1: user1, user2: user2} do
      [fdb_user1] = User.external_users(limit: 1)

      assert fdb_user1.ap_id
      assert fdb_user1.ap_id == user1.ap_id
      assert fdb_user1.id == user1.id

      [fdb_user2] = User.external_users(max_id: fdb_user1.id, limit: 1)

      assert fdb_user2.ap_id
      assert fdb_user2.ap_id == user2.ap_id
      assert fdb_user2.id == user2.id

      assert User.external_users(max_id: fdb_user2.id, limit: 1) == []
    end
  end

  describe "is_internal_user?/1" do
    test "non-internal user returns false" do
      user = insert(:user)
      refute User.is_internal_user?(user)
    end

    test "user with no nickname returns true" do
      user = insert(:user, %{nickname: nil})
      assert User.is_internal_user?(user)
    end

    test "user with internal-prefixed nickname returns true" do
      user = insert(:user, %{nickname: "internal.test"})
      assert User.is_internal_user?(user)
    end
  end

  describe "update_and_set_cache/1" do
    test "returns error when user is stale instead Ecto.StaleEntryError" do
      user = insert(:user)

      changeset = Ecto.Changeset.change(user, bio: "test")

      Repo.delete(user)

      assert {:error, %Ecto.Changeset{errors: [id: {"is stale", [stale: true]}], valid?: false}} =
               User.update_and_set_cache(changeset)
    end

    test "performs update cache if user updated" do
      user = insert(:user)
      assert {:ok, nil} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")

      changeset = Ecto.Changeset.change(user, bio: "test-bio")

      assert {:ok, %User{bio: "test-bio"} = user} = User.update_and_set_cache(changeset)
      assert {:ok, user} = Cachex.get(:user_cache, "ap_id:#{user.ap_id}")
      assert %User{bio: "test-bio"} = User.get_cached_by_ap_id(user.ap_id)
    end
  end

  describe "following/followers synchronization" do
    setup do: clear_config([:instance, :external_user_synchronization])

    test "updates the counters normally on following/getting a follow when disabled" do
      Pleroma.Config.put([:instance, :external_user_synchronization], false)
      user = insert(:user)

      other_user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following",
          ap_enabled: true
        )

      assert other_user.following_count == 0
      assert other_user.follower_count == 0

      {:ok, user} = Pleroma.User.follow(user, other_user)
      other_user = Pleroma.User.get_by_id(other_user.id)

      assert user.following_count == 1
      assert other_user.follower_count == 1
    end

    test "syncronizes the counters with the remote instance for the followed when enabled" do
      Pleroma.Config.put([:instance, :external_user_synchronization], false)

      user = insert(:user)

      other_user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following",
          ap_enabled: true
        )

      assert other_user.following_count == 0
      assert other_user.follower_count == 0

      Pleroma.Config.put([:instance, :external_user_synchronization], true)
      {:ok, _user} = User.follow(user, other_user)
      other_user = User.get_by_id(other_user.id)

      assert other_user.follower_count == 437
    end

    test "syncronizes the counters with the remote instance for the follower when enabled" do
      Pleroma.Config.put([:instance, :external_user_synchronization], false)

      user = insert(:user)

      other_user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following",
          ap_enabled: true
        )

      assert other_user.following_count == 0
      assert other_user.follower_count == 0

      Pleroma.Config.put([:instance, :external_user_synchronization], true)
      {:ok, other_user} = User.follow(other_user, user)

      assert other_user.following_count == 152
    end
  end

  describe "change_email/2" do
    setup do
      [user: insert(:user)]
    end

    test "blank email returns error", %{user: user} do
      assert {:error, %{errors: [email: {"can't be blank", _}]}} = User.change_email(user, "")
      assert {:error, %{errors: [email: {"can't be blank", _}]}} = User.change_email(user, nil)
    end

    test "non unique email returns error", %{user: user} do
      %{email: email} = insert(:user)

      assert {:error, %{errors: [email: {"has already been taken", _}]}} =
               User.change_email(user, email)
    end

    test "invalid email returns error", %{user: user} do
      assert {:error, %{errors: [email: {"has invalid format", _}]}} =
               User.change_email(user, "cofe")
    end

    test "changes email", %{user: user} do
      assert {:ok, %User{email: "cofe@cofe.party"}} = User.change_email(user, "cofe@cofe.party")
    end
  end

  describe "get_cached_by_nickname_or_id" do
    setup do
      local_user = insert(:user)
      remote_user = insert(:user, nickname: "nickname@example.com", local: false)

      [local_user: local_user, remote_user: remote_user]
    end

    setup do: clear_config([:instance, :limit_to_local_content])

    test "allows getting remote users by id no matter what :limit_to_local_content is set to", %{
      remote_user: remote_user
    } do
      Pleroma.Config.put([:instance, :limit_to_local_content], false)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.id)

      Pleroma.Config.put([:instance, :limit_to_local_content], true)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.id)

      Pleroma.Config.put([:instance, :limit_to_local_content], :unauthenticated)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.id)
    end

    test "disallows getting remote users by nickname without authentication when :limit_to_local_content is set to :unauthenticated",
         %{remote_user: remote_user} do
      Pleroma.Config.put([:instance, :limit_to_local_content], :unauthenticated)
      assert nil == User.get_cached_by_nickname_or_id(remote_user.nickname)
    end

    test "allows getting remote users by nickname with authentication when :limit_to_local_content is set to :unauthenticated",
         %{remote_user: remote_user, local_user: local_user} do
      Pleroma.Config.put([:instance, :limit_to_local_content], :unauthenticated)
      assert %User{} = User.get_cached_by_nickname_or_id(remote_user.nickname, for: local_user)
    end

    test "disallows getting remote users by nickname when :limit_to_local_content is set to true",
         %{remote_user: remote_user} do
      Pleroma.Config.put([:instance, :limit_to_local_content], true)
      assert nil == User.get_cached_by_nickname_or_id(remote_user.nickname)
    end

    test "allows getting local users by nickname no matter what :limit_to_local_content is set to",
         %{local_user: local_user} do
      Pleroma.Config.put([:instance, :limit_to_local_content], false)
      assert %User{} = User.get_cached_by_nickname_or_id(local_user.nickname)

      Pleroma.Config.put([:instance, :limit_to_local_content], true)
      assert %User{} = User.get_cached_by_nickname_or_id(local_user.nickname)

      Pleroma.Config.put([:instance, :limit_to_local_content], :unauthenticated)
      assert %User{} = User.get_cached_by_nickname_or_id(local_user.nickname)
    end
  end

  describe "update_email_notifications/2" do
    setup do
      user = insert(:user, email_notifications: %{"digest" => true})

      {:ok, user: user}
    end

    test "Notifications are updated", %{user: user} do
      true = user.email_notifications["digest"]
      assert {:ok, result} = User.update_email_notifications(user, %{"digest" => false})
      assert result.email_notifications["digest"] == false
    end
  end

  test "avatar fallback" do
    user = insert(:user)
    assert User.avatar_url(user) =~ "/images/avi.png"

    clear_config([:assets, :default_user_avatar], "avatar.png")

    user = User.get_cached_by_nickname_or_id(user.nickname)
    assert User.avatar_url(user) =~ "avatar.png"

    assert User.avatar_url(user, no_default: true) == nil
  end
end
