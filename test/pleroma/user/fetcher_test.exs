# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.FetcherTest do
  use Pleroma.DataCase, async: false
  @moduletag :mocked
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.User.Fetcher

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "building a user from AP id" do
    test "it returns a user" do
      user_id = "http://mastodon.example.org/users/admin"
      {:ok, user} = Fetcher.make_user_from_ap_id(user_id)
      assert user.ap_id == user_id
      assert user.nickname == "admin@mastodon.example.org"
      assert user.follower_address == "http://mastodon.example.org/users/admin/followers"
    end

    test "it returns a user that is invisible" do
      user_id = "http://mastodon.example.org/users/relay"
      {:ok, user} = Fetcher.make_user_from_ap_id(user_id)
      assert User.invisible?(user)
    end

    test "works for guppe actors" do
      user_id = "https://gup.pe/u/bernie2020"

      Tesla.Mock.mock(fn
        %{method: :get, url: ^user_id} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/guppe-actor.json"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = Fetcher.make_user_from_ap_id(user_id)

      assert user.name == "Bernie2020 group"
      assert user.actor_type == "Group"
    end

    test "works for bridgy actors" do
      user_id = "https://fed.brid.gy/jk.nipponalba.scot"

      Tesla.Mock.mock(fn
        %{method: :get, url: ^user_id} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/bridgy/actor.json"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = Fetcher.make_user_from_ap_id(user_id)

      assert user.actor_type == "Person"

      assert user.avatar == %{
               "type" => "Image",
               "url" => [%{"href" => "https://jk.nipponalba.scot/images/profile.jpg"}],
               "name" => "profile picture"
             }

      assert user.banner == %{
               "type" => "Image",
               "url" => [%{"href" => "https://jk.nipponalba.scot/images/profile.jpg"}],
               "name" => "profile picture"
             }
    end

    test "works for takahe actors" do
      user_id = "https://fedi.vision/@vote@fedi.vision/"

      Tesla.Mock.mock(fn
        %{method: :get, url: ^user_id} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/users_mock/takahe_user.json"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = Fetcher.make_user_from_ap_id(user_id)

      assert user.actor_type == "Person"

      assert [
               %{
                 "name" => "More details"
               }
             ] = user.fields
    end

    test "works for actors with malformed attachment fields" do
      user_id = "https://fedi.vision/@vote@fedi.vision/"

      Tesla.Mock.mock(fn
        %{method: :get, url: ^user_id} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/users_mock/nonsense_attachment_user.json"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = Fetcher.make_user_from_ap_id(user_id)

      assert user.actor_type == "Person"

      assert [] = user.fields
    end

    defp test_featured(inlined) do
      ap_id = "https://example.com/users/lain"

      featured_url = "https://example.com/users/lain/collections/featured"

      object_id = Ecto.UUID.generate()

      featured_data =
        "test/fixtures/mastodon/collections/featured.json"
        |> File.read!()
        |> String.replace("{{domain}}", "example.com")
        |> String.replace("{{nickname}}", "lain")
        |> String.replace("{{object_id}}", object_id)

      featured_ref = if inlined, do: Jason.decode!(featured_data), else: featured_url

      user_data =
        "test/fixtures/users_mock/user.json"
        |> File.read!()
        |> String.replace("{{nickname}}", "lain")
        |> Jason.decode!()
        |> Map.put("featured", featured_ref)
        |> Jason.encode!()

      object_url = "https://example.com/objects/#{object_id}"

      object_data =
        "test/fixtures/statuses/note.json"
        |> File.read!()
        |> String.replace("{{object_id}}", object_id)
        |> String.replace("{{nickname}}", "lain")

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: ^ap_id
        } ->
          %Tesla.Env{
            status: 200,
            body: user_data,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{
          method: :get,
          url: ^featured_url
        } ->
          %Tesla.Env{
            status: 200,
            body: featured_data,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{
          method: :get,
          url: ^object_url
        } ->
          %Tesla.Env{
            status: 200,
            body: object_data,
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = Fetcher.make_user_from_ap_id(ap_id)
      # wait for oban
      Pleroma.Tests.ObanHelpers.perform_all()

      assert user.featured_address == featured_url
      assert Map.has_key?(user.pinned_objects, object_url)

      in_db = Pleroma.User.get_by_ap_id(ap_id)
      assert in_db.featured_address == featured_url
      assert Map.has_key?(user.pinned_objects, object_url)

      assert %{data: %{"id" => ^object_url}} = Object.get_by_ap_id(object_url)
    end

    test "fetches user featured collection by bare id" do
      test_featured(false)
    end

    test "fetches user featured collection when embedded" do
      test_featured(true)
    end
  end

  test "fetches user featured collection using the first property" do
    featured_url = "https://friendica.example.com/featured/raha"
    first_url = "https://friendica.example.com/featured/raha?page=1"

    featured_data =
      "test/fixtures/friendica/friendica_featured_collection.json"
      |> File.read!()

    page_data =
      "test/fixtures/friendica/friendica_featured_collection_first.json"
      |> File.read!()

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^featured_url
      } ->
        %Tesla.Env{
          status: 200,
          body: featured_data,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^first_url
      } ->
        %Tesla.Env{
          status: 200,
          body: page_data,
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, ^featured_url, data} = Fetcher.process_featured_collection(featured_url)
    assert Map.has_key?(data, "http://inserted")
  end

  test "fetches user featured when it has string IDs" do
    featured_url = "https://example.com/users/alisaie/collections/featured"
    dead_url = "https://example.com/users/alisaie/statuses/108311386746229284"

    featured_data =
      "test/fixtures/mastodon/featured_collection.json"
      |> File.read!()

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^featured_url
      } ->
        %Tesla.Env{
          status: 200,
          body: featured_data,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^dead_url
      } ->
        %Tesla.Env{
          status: 404,
          body: "{}",
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, ^featured_url, %{}} = Fetcher.process_featured_collection(featured_url)
  end

  test "fetches avatar description" do
    user_id = "https://example.com/users/nicole"

    user_data =
      "test/fixtures/users_mock/user.json"
      |> File.read!()
      |> String.replace("{{nickname}}", "nicole")
      |> Jason.decode!()
      |> Map.delete("featured")
      |> Map.update("icon", %{}, fn image -> Map.put(image, "name", "image description") end)
      |> Jason.encode!()

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^user_id
      } ->
        %Tesla.Env{
          status: 200,
          body: user_data,
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, user} = Fetcher.make_user_from_ap_id(user_id)

    assert user.avatar["name"] == "image description"
  end

  describe "fetch_follow_information_for_user" do
    test "synchronizes following/followers counters" do
      user =
        insert(:user,
          local: false,
          follower_address: "http://remote.org/users/fuser2/followers",
          following_address: "http://remote.org/users/fuser2/following"
        )

      {:ok, info} = Fetcher.fetch_follow_information_for_user(user)
      assert info.follower_count == 527
      assert info.following_count == 267
    end

    test "detects hidden followers" do
      mock(fn env ->
        case env.url do
          "http://remote.org/users/masto_closed/followers?page=1" ->
            %Tesla.Env{status: 403, body: ""}

          _ ->
            apply(HttpRequestMock, :request, [env])
        end
      end)

      user =
        insert(:user,
          local: false,
          follower_address: "http://remote.org/users/masto_closed/followers",
          following_address: "http://remote.org/users/masto_closed/following"
        )

      {:ok, follow_info} = Fetcher.fetch_follow_information_for_user(user)
      assert follow_info.hide_followers == true
      assert follow_info.hide_follows == false
    end

    test "detects hidden follows" do
      mock(fn env ->
        case env.url do
          "http://remote.org/users/masto_closed/following?page=1" ->
            %Tesla.Env{status: 403, body: ""}

          _ ->
            apply(HttpRequestMock, :request, [env])
        end
      end)

      user =
        insert(:user,
          local: false,
          follower_address: "http://remote.org/users/masto_closed/followers",
          following_address: "http://remote.org/users/masto_closed/following"
        )

      {:ok, follow_info} = Fetcher.fetch_follow_information_for_user(user)
      assert follow_info.hide_followers == false
      assert follow_info.hide_follows == true
    end

    test "detects hidden follows/followers for friendica" do
      user =
        insert(:user,
          local: false,
          follower_address: "http://remote.org/followers/fuser3",
          following_address: "http://remote.org/following/fuser3"
        )

      {:ok, follow_info} = Fetcher.fetch_follow_information_for_user(user)
      assert follow_info.hide_followers == true
      assert follow_info.follower_count == 296
      assert follow_info.following_count == 32
      assert follow_info.hide_follows == true
    end

    test "doesn't crash when follower and following counters are hidden" do
      mock(fn env ->
        case env.url do
          "http://remote.org/users/masto_hidden_counters/following" ->
            json(
              %{
                "@context" => "https://www.w3.org/ns/activitystreams",
                "id" => "http://remote.org/users/masto_hidden_counters/following"
              },
              headers: HttpRequestMock.activitypub_object_headers()
            )

          "http://remote.org/users/masto_hidden_counters/following?page=1" ->
            %Tesla.Env{status: 403, body: ""}

          "http://remote.org/users/masto_hidden_counters/followers" ->
            json(
              %{
                "@context" => "https://www.w3.org/ns/activitystreams",
                "id" => "http://remote.org/users/masto_hidden_counters/followers"
              },
              headers: HttpRequestMock.activitypub_object_headers()
            )

          "http://remote.org/users/masto_hidden_counters/followers?page=1" ->
            %Tesla.Env{status: 403, body: ""}
        end
      end)

      user =
        insert(:user,
          local: false,
          follower_address: "http://remote.org/users/masto_hidden_counters/followers",
          following_address: "http://remote.org/users/masto_hidden_counters/following"
        )

      {:ok, follow_info} = Fetcher.fetch_follow_information_for_user(user)

      assert follow_info.hide_followers == true
      assert follow_info.follower_count == 0
      assert follow_info.hide_follows == true
      assert follow_info.following_count == 0
    end

    test "treats missing follow* addresses as a private collection" do
      user =
        insert(:user,
          local: false,
          follower_address: nil,
          following_address: nil
        )

      {:ok, follow_info} = Fetcher.fetch_follow_information_for_user(user)

      assert follow_info.hide_followers == true
      assert follow_info.hide_followers_count == true
      assert follow_info.follower_count == 0
      assert follow_info.hide_follows == true
      assert follow_info.hide_follows_count == true
      assert follow_info.following_count == 0
    end
  end

  describe "maybe_update_follow_information/1" do
    setup do
      clear_config([:instance, :external_user_synchronization], true)

      user = %{
        local: false,
        ap_id: "https://gensokyo.2hu/users/raymoo",
        following_address: "https://gensokyo.2hu/users/following",
        follower_address: "https://gensokyo.2hu/users/followers",
        type: "Person",
        hide_follows: false,
        hide_follows_count: false,
        following_count: 15,
        hide_followers: false,
        hide_followers_count: false,
        follower_count: 7
      }

      %{user: user}
    end

    test "assumes private counters when it can't fetch the info", %{user: user} do
      refute user.hide_follows
      refute user.hide_follows_count
      refute user.hide_followers
      refute user.hide_followers_count

      assert capture_log(fn ->
               user = Fetcher.maybe_update_follow_information(user)
               assert user.hide_follows
               assert user.hide_follows_count
               assert user.following_count == 0
               assert user.hide_followers
               assert user.hide_followers_count
               assert user.follower_count == 0
             end) =~
               "Failed to fetch follower/ing collection #{user.follower_address}; assuming private"
    end

    test "it just returns the input if the user has no following/follower addresses", %{
      user: user
    } do
      user =
        user
        |> Map.put(:following_address, nil)
        |> Map.put(:follower_address, nil)

      refute capture_log(fn ->
               assert ^user = Fetcher.maybe_update_follow_information(user)
             end) =~ "Follower/Following counter update for #{user.ap_id} failed"
    end
  end

  describe "handling of clashing nicknames" do
    test "renames an existing user with a clashing nickname and a different ap id" do
      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/harinezumigari"
        )

      %{
        nickname: orig_user.nickname,
        ap_id: orig_user.ap_id <> "part_2"
      }
      |> Fetcher.maybe_handle_clashing_nickname()

      user = User.get_by_id(orig_user.id)

      assert user.nickname == "#{orig_user.id}.admin@mastodon.example.org"
    end

    test "does nothing with a clashing nickname and the same ap id" do
      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/harinezumigari"
        )

      %{
        nickname: orig_user.nickname,
        ap_id: orig_user.ap_id
      }
      |> Fetcher.maybe_handle_clashing_nickname()

      user = User.get_by_id(orig_user.id)

      assert user.nickname == orig_user.nickname
    end
  end

  test "allow fetching of accounts with an empty string name field" do
    Tesla.Mock.mock(fn
      %{method: :get, url: "https://princess.cat/users/mewmew"} ->
        file = File.read!("test/fixtures/mewmew_no_name.json")
        %Tesla.Env{status: 200, body: file, headers: HttpRequestMock.activitypub_object_headers()}
    end)

    {:ok, user} = Fetcher.make_user_from_ap_id("https://princess.cat/users/mewmew")
    assert user.name == " "
  end

  test "process_featured_collection will ignore unsupported values" do
    assert {:error, :invalid_type} ==
             Fetcher.process_featured_collection(%{
               "type" => "CollectionThatIsNotRealAndCannotHurtMe",
               "first" => "https://social.example/users/alice/collections/featured?page=true"
             })
  end
end
