# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.ContainmentTest do
  use Pleroma.DataCase

  alias Pleroma.Object.Containment
  alias Pleroma.User

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "general origin containment" do
    test "handles completly actorless objects gracefully" do
      assert :ok ==
               Containment.contain_origin("https://glaceon.social/statuses/123", %{
                 "deleted" => "2019-10-30T05:48:50.249606Z",
                 "formerType" => "Note",
                 "id" => "https://glaceon.social/statuses/123",
                 "type" => "Tombstone"
               })
    end

    test "errors for spoofed actors" do
      assert :error ==
               Containment.contain_origin("https://glaceon.social/statuses/123", %{
                 "actor" => "https://otp.akkoma.dev/users/you",
                 "id" => "https://glaceon.social/statuses/123",
                 "type" => "Note"
               })
    end

    test "errors for spoofed attributedTo" do
      assert :error ==
               Containment.contain_origin("https://glaceon.social/statuses/123", %{
                 "attributedTo" => "https://otp.akkoma.dev/users/you",
                 "id" => "https://glaceon.social/statuses/123",
                 "type" => "Note"
               })
    end

    test "accepts valid actors" do
      assert :ok ==
               Containment.contain_origin("https://glaceon.social/statuses/123", %{
                 "actor" => "https://glaceon.social/users/monorail",
                 "attributedTo" => "https://glaceon.social/users/monorail",
                 "id" => "https://glaceon.social/statuses/123",
                 "type" => "Note"
               })

      assert :ok ==
               Containment.contain_origin("https://glaceon.social/statuses/123", %{
                 "actor" => "https://glaceon.social/users/monorail",
                 "id" => "https://glaceon.social/statuses/123",
                 "type" => "Note"
               })

      assert :ok ==
               Containment.contain_origin("https://glaceon.social/statuses/123", %{
                 "attributedTo" => "https://glaceon.social/users/monorail",
                 "id" => "https://glaceon.social/statuses/123",
                 "type" => "Note"
               })
    end

    test "contain_origin_from_id() catches obvious spoofing attempts" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json"
      }

      :error =
        Containment.contain_origin_from_id(
          "http://example.org/~alyssa/activities/1234.json",
          data
        )
    end

    test "contain_origin_from_id() allows alternate IDs within the same origin domain" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json"
      }

      :ok =
        Containment.contain_origin_from_id(
          "http://example.com/~alyssa/activities/1234",
          data
        )
    end

    test "contain_origin_from_id() allows matching IDs" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json"
      }

      :ok =
        Containment.contain_origin_from_id(
          "http://example.com/~alyssa/activities/1234.json",
          data
        )
    end

    test "contain_id_to_fetch() refuses alternate IDs within the same origin domain" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json",
        "url" => "http://example.com/@alyssa/status/1234"
      }

      :error =
        Containment.contain_id_to_fetch(
          "http://example.com/~alyssa/activities/1234",
          data
        )
    end

    test "contain_id_to_fetch() allows matching IDs" do
      data = %{
        "id" => "http://example.com/~alyssa/activities/1234.json/"
      }

      :ok =
        Containment.contain_id_to_fetch(
          "http://example.com/~alyssa/activities/1234.json/",
          data
        )

      :ok =
        Containment.contain_id_to_fetch(
          "http://example.com/~alyssa/activities/1234.json",
          data
        )
    end

    test "contain_id_to_fetch() allows fragments and normalises domain casing" do
      data = %{
        "id" => "http://example.com/users/capybara",
        "url" => "http://example.com/@capybara"
      }

      assert :ok ==
               Containment.contain_id_to_fetch(
                 "http://EXAMPLE.com/users/capybara#key",
                 data
               )
    end

    test "users cannot be collided through fake direction spoofing attempts" do
      _user =
        insert(:user, %{
          nickname: "rye@niu.moe",
          local: false,
          ap_id: "https://niu.moe/users/rye",
          follower_address: User.ap_followers(%User{nickname: "rye@niu.moe"})
        })

      # Fetch from an attempted spoof id will suceed, but automatically retrieve
      # the real data from the homeserver instead of naïvely using the spoof
      {:ok, fetched_user} = User.get_or_fetch_by_ap_id("https://n1u.moe/users/rye")

      refute fetched_user.name == "evil rye"
      refute fetched_user.raw_bio == "boooo!"
      assert fetched_user.name == "♡ rye ♡"
      assert fetched_user.nickname == "rye@niu.moe"
    end

    test "contain_origin_from_id() gracefully handles cases where no ID is present" do
      data = %{
        "type" => "Create",
        "object" => %{
          "id" => "http://example.net/~alyssa/activities/1234",
          "attributedTo" => "http://example.org/~alyssa"
        },
        "actor" => "http://example.com/~bob"
      }

      :error =
        Containment.contain_origin_from_id("http://example.net/~alyssa/activities/1234", data)
    end
  end

  describe "containment of children" do
    test "contain_child() catches spoofing attempts" do
      data = %{
        "id" => "http://example.com/whatever",
        "type" => "Create",
        "object" => %{
          "id" => "http://example.net/~alyssa/activities/1234",
          "attributedTo" => "http://example.org/~alyssa"
        },
        "actor" => "http://example.com/~bob"
      }

      :error = Containment.contain_child(data)
    end

    test "contain_child() allows correct origins" do
      data = %{
        "id" => "http://example.org/~alyssa/activities/5678",
        "type" => "Create",
        "object" => %{
          "id" => "http://example.org/~alyssa/activities/1234",
          "attributedTo" => "http://example.org/~alyssa"
        },
        "actor" => "http://example.org/~alyssa"
      }

      :ok = Containment.contain_child(data)
    end
  end
end
