# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.FetcherTest do
  use Pleroma.DataCase, async: false
  @moduletag :mocked

  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher

  import Mock
  import Tesla.Mock

  defp spoofed_object_with_ids(
         id \\ "https://patch.cx/objects/spoof",
         actor_id \\ "https://patch.cx/users/rin"
       ) do
    File.read!("test/fixtures/spoofed-object.json")
    |> Jason.decode!()
    |> Map.put("id", id)
    |> Map.put("actor", actor_id)
    |> Jason.encode!()
  end

  setup do
    mock(fn
      %{method: :get, url: "https://mastodon.example.org/users/userisgone"} ->
        %Tesla.Env{status: 410}

      %{method: :get, url: "https://mastodon.example.org/users/userisgone404"} ->
        %Tesla.Env{status: 404}

      # Spoof: wrong Content-Type
      %{
        method: :get,
        url: "https://patch.cx/objects/spoof_content_type.json"
      } ->
        %Tesla.Env{
          status: 200,
          url: "https://patch.cx/objects/spoof_content_type.json",
          headers: [{"content-type", "application/json"}],
          body: spoofed_object_with_ids("https://patch.cx/objects/spoof_content_type.json")
        }

      # Spoof: no Content-Type
      %{
        method: :get,
        url: "https://patch.cx/objects/spoof_content_type"
      } ->
        %Tesla.Env{
          status: 200,
          url: "https://patch.cx/objects/spoof_content_type",
          headers: [],
          body: spoofed_object_with_ids("https://patch.cx/objects/spoof_content_type")
        }

      %{method: :get, url: "https://octodon.social/users/cwebber/statuses/111647596861000656"} ->
        %Tesla.Env{status: 403}

      # Spoof: mismatching ids
      # Variant 1: Non-exisitng fake id
      %{
        method: :get,
        url:
          "https://patch.cx/media/03ca3c8b4ac3ddd08bf0f84be7885f2f88de0f709112131a22d83650819e36c2.json"
      } ->
        %Tesla.Env{
          status: 200,
          url:
            "https://patch.cx/media/03ca3c8b4ac3ddd08bf0f84be7885f2f88de0f709112131a22d83650819e36c2.json",
          headers: [{"content-type", "application/activity+json"}],
          body: spoofed_object_with_ids()
        }

      %{method: :get, url: "https://patch.cx/objects/spoof"} ->
        %Tesla.Env{
          status: 404,
          url: "https://patch.cx/objects/spoof",
          headers: [],
          body: "Not found"
        }

      # Varaint 2: two-stage payload
      %{method: :get, url: "https://patch.cx/media/spoof_stage1.json"} ->
        %Tesla.Env{
          status: 200,
          url: "https://patch.cx/media/spoof_stage1.json",
          headers: [{"content-type", "application/activity+json"}],
          body: spoofed_object_with_ids("https://patch.cx/media/spoof_stage2.json")
        }

      %{method: :get, url: "https://patch.cx/media/spoof_stage2.json"} ->
        %Tesla.Env{
          status: 200,
          url: "https://patch.cx/media/spoof_stage2.json",
          headers: [{"content-type", "application/activity+json"}],
          body: spoofed_object_with_ids("https://patch.cx/media/unpredictable.json")
        }

      # Spoof: cross-domain redirect with original domain id
      %{method: :get, url: "https://patch.cx/objects/spoof_media_redirect1"} ->
        %Tesla.Env{
          status: 200,
          url: "https://media.patch.cx/objects/spoof",
          headers: [{"content-type", "application/activity+json"}],
          body: spoofed_object_with_ids("https://patch.cx/objects/spoof_media_redirect1")
        }

      # Spoof: cross-domain redirect with final domain id
      %{method: :get, url: "https://patch.cx/objects/spoof_media_redirect2"} ->
        %Tesla.Env{
          status: 200,
          url: "https://media.patch.cx/objects/spoof_media_redirect2",
          headers: [{"content-type", "application/activity+json"}],
          body: spoofed_object_with_ids("https://media.patch.cx/objects/spoof_media_redirect2")
        }

      # No-Spoof: same domain redirect
      %{method: :get, url: "https://patch.cx/objects/spoof_redirect"} ->
        %Tesla.Env{
          status: 200,
          url: "https://patch.cx/objects/spoof_redirect",
          headers: [{"content-type", "application/activity+json"}],
          body: spoofed_object_with_ids("https://patch.cx/objects/spoof_redirect")
        }

      # Spoof: Actor from another domain
      %{method: :get, url: "https://patch.cx/objects/spoof_foreign_actor"} ->
        %Tesla.Env{
          status: 200,
          url: "https://patch.cx/objects/spoof_foreign_actor",
          headers: [{"content-type", "application/activity+json"}],
          body:
            spoofed_object_with_ids(
              "https://patch.cx/objects/spoof_foreign_actor",
              "https://not.patch.cx/users/rin"
            )
        }

      env ->
        apply(HttpRequestMock, :request, [env])
    end)

    :ok
  end

  describe "error cases" do
    setup do
      mock(fn
        %{method: :get, url: "https://social.sakamoto.gq/notice/9wTkLEnuq47B25EehM"} ->
          %Tesla.Env{
            status: 200,
            url: "https://social.sakamoto.gq/objects/f20f2497-66d9-4a52-a2e1-1be2a39c32c1",
            body: File.read!("test/fixtures/fetch_mocks/9wTkLEnuq47B25EehM.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        %{method: :get, url: "https://social.sakamoto.gq/users/eal"} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/fetch_mocks/eal.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        %{method: :get, url: "https://busshi.moe/users/tuxcrafting/statuses/104410921027210069"} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/fetch_mocks/104410921027210069.json"),
            headers: HttpRequestMock.activitypub_object_headers()
          }

        %{method: :get, url: "https://busshi.moe/users/tuxcrafting"} ->
          %Tesla.Env{
            status: 500
          }

        %{
          method: :get,
          url: "https://stereophonic.space/objects/02997b83-3ea7-4b63-94af-ef3aa2d4ed17"
        } ->
          %Tesla.Env{
            status: 500
          }
      end)

      :ok
    end

    @tag capture_log: true
    test "it works when fetching the OP actor errors out" do
      # Here we simulate a case where the author of the OP can't be read
      assert {:ok, _} =
               Fetcher.fetch_object_from_id(
                 "https://social.sakamoto.gq/notice/9wTkLEnuq47B25EehM"
               )
    end
  end

  describe "max thread distance restriction" do
    @ap_id "http://mastodon.example.org/@admin/99541947525187367"
    setup do: clear_config([:instance, :federation_incoming_replies_max_depth])

    test "it returns thread depth exceeded error if thread depth is exceeded" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      assert {:error, :allowed_depth} = Fetcher.fetch_object_from_id(@ap_id, depth: 1)
    end

    test "it fetches object if max thread depth is restricted to 0 and depth is not specified" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 0)

      assert {:ok, _} = Fetcher.fetch_object_from_id(@ap_id)
    end

    test "it fetches object if requested depth does not exceed max thread depth" do
      clear_config([:instance, :federation_incoming_replies_max_depth], 10)

      assert {:ok, _} = Fetcher.fetch_object_from_id(@ap_id, depth: 10)
    end
  end

  describe "actor origin containment" do
    test "it rejects objects with a bogus origin" do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity.json")
    end

    test "it rejects objects when attributedTo is wrong (variant 1)" do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity2.json")
    end

    test "it rejects objects when attributedTo is wrong (variant 2)" do
      {:error, _} = Fetcher.fetch_object_from_id("https://info.pleroma.site/activity3.json")
    end
  end

  describe "fetcher security and auth checks" do
    test "it does not fetch a spoofed object without content type" do
      assert {:error, {:content_type, nil}} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/objects/spoof_content_type"
               )
    end

    test "it does not fetch a spoofed object with wrong content type" do
      assert {:error, {:content_type, _}} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/objects/spoof_content_type.json"
               )
    end

    test "it does not fetch a spoofed object with id different from URL" do
      assert {:error, :id_mismatch} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/media/03ca3c8b4ac3ddd08bf0f84be7885f2f88de0f709112131a22d83650819e36c2.json"
               )

      assert {:error, :id_mismatch} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/media/spoof_stage1.json"
               )
    end

    test "it does not fetch an object via cross-domain redirects (initial id)" do
      assert {:error, {:cross_domain_redirect, true}} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/objects/spoof_media_redirect1"
               )
    end

    test "it does not fetch an object via cross-domain redirects (final id)" do
      assert {:error, {:cross_domain_redirect, true}} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/objects/spoof_media_redirect2"
               )
    end

    test "it accepts same-domain redirects" do
      assert {:ok, %{"id" => id} = _object} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/objects/spoof_redirect"
               )

      assert id == "https://patch.cx/objects/spoof_redirect"
    end

    test "it does not fetch a spoofed object with a foreign actor" do
      assert {:error, _} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://patch.cx/objects/spoof_foreign_actor"
               )
    end

    test "it does not fetch from localhost" do
      assert {:error, :local_resource} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 Pleroma.Web.Endpoint.url() <> "/spoof_local"
               )
    end
  end

  describe "fetching an object" do
    test "it fetches an object" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert _activity = Activity.get_create_by_object_ap_id(object.data["id"])

      {:ok, object_again} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert [attachment] = object.data["attachment"]
      assert is_list(attachment["url"])

      assert object == object_again
    end

    test "Return MRF reason when fetched status is rejected by one" do
      clear_config([:mrf_keyword, :reject], ["yeah"])
      clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.KeywordPolicy])

      assert {:reject, "[KeywordPolicy] Matches with rejected keyword"} ==
               Fetcher.fetch_object_from_id(
                 "http://mastodon.example.org/@admin/99541947525187367"
               )
    end

    test "does not fetch anything from a rejected instance" do
      clear_config([:mrf_simple, :reject], [{"evil.example.org", "i said so"}])

      assert {:reject, _} =
               Fetcher.fetch_object_from_id("http://evil.example.org/@admin/99541947525187367")
    end

    test "does not fetch anything if mrf_simple accept is on" do
      clear_config([:mrf_simple, :accept], [{"mastodon.example.org", "i said so"}])
      clear_config([:mrf_simple, :reject], [])

      assert {:reject, _} =
               Fetcher.fetch_object_from_id(
                 "http://notlisted.example.org/@admin/99541947525187367"
               )

      assert {:ok, _object} =
               Fetcher.fetch_object_from_id(
                 "http://mastodon.example.org/@admin/99541947525187367"
               )
    end

    test "it resets instance reachability on successful fetch" do
      id = "http://mastodon.example.org/@admin/99541947525187367"
      Instances.set_consistently_unreachable(id)
      refute Instances.reachable?(id)

      {:ok, _object} =
        Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert Instances.reachable?(id)
    end
  end

  describe "implementation quirks" do
    test "it can fetch plume articles" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://baptiste.gelez.xyz/~/PlumeDevelopment/this-month-in-plume-june-2018/"
        )

      assert object
    end

    test "it can fetch peertube videos" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://peertube.moe/videos/watch/df5f464b-be8d-46fb-ad81-2d4c2d1630e3"
        )

      assert object
    end

    test "it can fetch Mobilizon events" do
      {:ok, object} =
        Fetcher.fetch_object_from_id(
          "https://mobilizon.org/events/252d5816-00a3-4a89-a66f-15bf65c33e39"
        )

      assert object
    end

    test "it can fetch wedistribute articles" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("https://wedistribute.org/wp-json/pterotype/v1/object/85810")

      assert object
    end

    test "all objects with fake directions are rejected by the object fetcher" do
      assert {:error, _} =
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://info.pleroma.site/activity4.json"
               )
    end

    test "handle HTTP 410 Gone response" do
      assert {:error, :not_found} ==
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://mastodon.example.org/users/userisgone"
               )
    end

    test "handle HTTP 404 response" do
      assert {:error, :not_found} ==
               Fetcher.fetch_and_contain_remote_object_from_id(
                 "https://mastodon.example.org/users/userisgone404"
               )
    end

    test "it can fetch pleroma polls with attachments" do
      {:ok, object} =
        Fetcher.fetch_object_from_id("https://patch.cx/objects/tesla_mock/poll_attachment")

      assert object
    end
  end

  describe "pruning" do
    test "it can refetch pruned objects" do
      object_id = "http://mastodon.example.org/@admin/99541947525187367"

      {:ok, object} = Fetcher.fetch_object_from_id(object_id)

      assert object

      {:ok, _object} = Object.prune(object)

      refute Object.get_by_ap_id(object_id)

      {:ok, %Object{} = object_two} = Fetcher.fetch_object_from_id(object_id)

      assert object.data["id"] == object_two.data["id"]
      assert object.id != object_two.id
    end
  end

  describe "signed fetches" do
    setup do: clear_config([:activitypub, :sign_object_fetches])

    test_with_mock "it signs fetches when configured to do so",
                   Pleroma.Signature,
                   [:passthrough],
                   [] do
      clear_config([:activitypub, :sign_object_fetches], true)

      Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      assert called(Pleroma.Signature.sign(:_, :_))
    end

    test_with_mock "it doesn't sign fetches when not configured to do so",
                   Pleroma.Signature,
                   [:passthrough],
                   [] do
      clear_config([:activitypub, :sign_object_fetches], false)

      Fetcher.fetch_object_from_id("http://mastodon.example.org/@admin/99541947525187367")

      refute called(Pleroma.Signature.sign(:_, :_))
    end
  end

  describe "refetching" do
    setup do
      object1 = %{
        "id" => "https://mastodon.social/1",
        "actor" => "https://mastodon.social/users/emelie",
        "attributedTo" => "https://mastodon.social/users/emelie",
        "type" => "Note",
        "content" => "test 1",
        "bcc" => [],
        "bto" => [],
        "cc" => [],
        "to" => [],
        "summary" => ""
      }

      object2 = %{
        "id" => "https://mastodon.social/2",
        "actor" => "https://mastodon.social/users/emelie",
        "attributedTo" => "https://mastodon.social/users/emelie",
        "type" => "Note",
        "content" => "test 2",
        "bcc" => [],
        "bto" => [],
        "cc" => [],
        "to" => [],
        "summary" => "",
        "formerRepresentations" => %{
          "type" => "OrderedCollection",
          "orderedItems" => [
            %{
              "type" => "Note",
              "content" => "orig 2",
              "actor" => "https://mastodon.social/users/emelie",
              "attributedTo" => "https://mastodon.social/users/emelie",
              "bcc" => [],
              "bto" => [],
              "cc" => [],
              "to" => [],
              "summary" => ""
            }
          ],
          "totalItems" => 1
        }
      }

      mock(fn
        %{
          method: :get,
          url: "https://mastodon.social/1"
        } ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/activity+json"}],
            body: Jason.encode!(object1)
          }

        %{
          method: :get,
          url: "https://mastodon.social/2"
        } ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/activity+json"}],
            body: Jason.encode!(object2)
          }

        %{
          method: :get,
          url: "https://mastodon.social/users/emelie/collections/featured"
        } ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/activity+json"}],
            body:
              Jason.encode!(%{
                "id" => "https://mastodon.social/users/emelie/collections/featured",
                "type" => "OrderedCollection",
                "actor" => "https://mastodon.social/users/emelie",
                "attributedTo" => "https://mastodon.social/users/emelie",
                "orderedItems" => [],
                "totalItems" => 0
              })
          }

        env ->
          apply(HttpRequestMock, :request, [env])
      end)

      %{object1: object1, object2: object2}
    end

    test "it keeps formerRepresentations if remote does not have this attr", %{object1: object1} do
      full_object1 =
        object1
        |> Map.merge(%{
          "formerRepresentations" => %{
            "type" => "OrderedCollection",
            "orderedItems" => [
              %{
                "type" => "Note",
                "content" => "orig 2",
                "actor" => "https://mastodon.social/users/emelie",
                "attributedTo" => "https://mastodon.social/users/emelie",
                "bcc" => [],
                "bto" => [],
                "cc" => [],
                "to" => [],
                "summary" => ""
              }
            ],
            "totalItems" => 1
          }
        })

      {:ok, o} = Object.create(full_object1)

      assert {:ok, refetched} = Fetcher.refetch_object(o)

      assert %{"formerRepresentations" => %{"orderedItems" => [%{"content" => "orig 2"}]}} =
               refetched.data
    end

    test "it uses formerRepresentations from remote if possible", %{object2: object2} do
      {:ok, o} = Object.create(object2)

      assert {:ok, refetched} = Fetcher.refetch_object(o)

      assert %{"formerRepresentations" => %{"orderedItems" => [%{"content" => "orig 2"}]}} =
               refetched.data
    end

    test "it replaces formerRepresentations with the one from remote", %{object2: object2} do
      full_object2 =
        object2
        |> Map.merge(%{
          "content" => "mew mew #def",
          "formerRepresentations" => %{
            "type" => "OrderedCollection",
            "orderedItems" => [
              %{"type" => "Note", "content" => "mew mew 2"}
            ],
            "totalItems" => 1
          }
        })

      {:ok, o} = Object.create(full_object2)

      assert {:ok, refetched} = Fetcher.refetch_object(o)

      assert %{
               "content" => "test 2",
               "formerRepresentations" => %{"orderedItems" => [%{"content" => "orig 2"}]}
             } = refetched.data
    end

    test "it adds to formerRepresentations if the remote does not have one and the object has changed",
         %{object1: object1} do
      full_object1 =
        object1
        |> Map.merge(%{
          "content" => "mew mew #def",
          "formerRepresentations" => %{
            "type" => "OrderedCollection",
            "orderedItems" => [
              %{"type" => "Note", "content" => "mew mew 1"}
            ],
            "totalItems" => 1
          }
        })

      {:ok, o} = Object.create(full_object1)

      assert {:ok, refetched} = Fetcher.refetch_object(o)

      assert %{
               "content" => "test 1",
               "formerRepresentations" => %{
                 "orderedItems" => [
                   %{"content" => "mew mew #def"},
                   %{"content" => "mew mew 1"}
                 ],
                 "totalItems" => 2
               }
             } = refetched.data
    end
  end

  describe "fetch with history" do
    setup do
      object2 = %{
        "id" => "https://mastodon.social/2",
        "actor" => "https://mastodon.social/users/emelie",
        "attributedTo" => "https://mastodon.social/users/emelie",
        "type" => "Note",
        "content" => "test 2",
        "bcc" => [],
        "bto" => [],
        "cc" => ["https://mastodon.social/users/emelie/followers"],
        "to" => [],
        "summary" => "",
        "formerRepresentations" => %{
          "type" => "OrderedCollection",
          "orderedItems" => [
            %{
              "type" => "Note",
              "content" => "orig 2",
              "actor" => "https://mastodon.social/users/emelie",
              "attributedTo" => "https://mastodon.social/users/emelie",
              "bcc" => [],
              "bto" => [],
              "cc" => ["https://mastodon.social/users/emelie/followers"],
              "to" => [],
              "summary" => ""
            }
          ],
          "totalItems" => 1
        }
      }

      mock(fn
        %{
          method: :get,
          url: "https://mastodon.social/2"
        } ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/activity+json"}],
            body: Jason.encode!(object2)
          }

        %{
          method: :get,
          url: "https://mastodon.social/users/emelie/collections/featured"
        } ->
          %Tesla.Env{
            status: 200,
            headers: [{"content-type", "application/activity+json"}],
            body:
              Jason.encode!(%{
                "id" => "https://mastodon.social/users/emelie/collections/featured",
                "type" => "OrderedCollection",
                "actor" => "https://mastodon.social/users/emelie",
                "attributedTo" => "https://mastodon.social/users/emelie",
                "orderedItems" => [],
                "totalItems" => 0
              })
          }

        env ->
          apply(HttpRequestMock, :request, [env])
      end)

      %{object2: object2}
    end

    test "it gets history", %{object2: object2} do
      {:ok, object} = Fetcher.fetch_object_from_id(object2["id"])

      assert %{
               "formerRepresentations" => %{
                 "type" => "OrderedCollection",
                 "orderedItems" => [%{}]
               }
             } = object.data
    end
  end

  describe "get_object/1" do
    test "should return ok if the content type is application/activity+json" do
      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://mastodon.social/2"
        } ->
          %Tesla.Env{
            status: 200,
            url: "https://mastodon.social/2",
            headers: [{"content-type", "application/activity+json"}],
            body: "{}"
          }
      end)

      assert {:ok, _, "{}"} = Fetcher.get_object("https://mastodon.social/2")
    end

    test "should return ok if the content type is application/ld+json with a profile" do
      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://mastodon.social/2"
        } ->
          %Tesla.Env{
            status: 200,
            url: "https://mastodon.social/2",
            headers: [
              {"content-type",
               "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""}
            ],
            body: "{}"
          }
      end)

      assert {:ok, _, "{}"} = Fetcher.get_object("https://mastodon.social/2")
    end

    test "should not return ok with other content types" do
      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://mastodon.social/2"
        } ->
          %Tesla.Env{
            status: 200,
            url: "https://mastodon.social/2",
            headers: [{"content-type", "application/json"}],
            body: "{}"
          }
      end)

      assert {:error, {:content_type, "application/json"}} =
               Fetcher.get_object("https://mastodon.social/2")
    end

    test "returns the url after redirects" do
      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: "https://mastodon.social/5"
        } ->
          %Tesla.Env{
            status: 200,
            url: "https://mastodon.social/7",
            headers: [{"content-type", "application/activity+json"}],
            body: "{}"
          }
      end)

      assert {:ok, "https://mastodon.social/7", "{}"} =
               Fetcher.get_object("https://mastodon.social/5")
    end
  end
end
