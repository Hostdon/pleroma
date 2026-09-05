# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceControllerTest do
  # TODO: Should not need Cachex
  use Pleroma.Web.ConnCase, async: false

  alias Pleroma.User
  import Pleroma.Factory

  test "get instance information", %{conn: conn} do
    clear_config([:instance, :languages], ["en", "ja"])
    conn = get(conn, "/api/v1/instance")
    assert result = json_response_and_validate_schema(conn, 200)
    email = Pleroma.Config.get([:instance, :email])

    thumbnail = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :instance_thumbnail])
    background = Pleroma.Web.Endpoint.url() <> Pleroma.Config.get([:instance, :background_image])

    # if no WebFinger domain is configured (without protocol)
    uri = Pleroma.Web.Endpoint.host()

    # Note: not checking for "max_toot_chars" since it's optional
    assert %{
             "uri" => ^uri,
             "title" => _,
             "description" => _,
             "short_description" => _,
             "version" => _,
             "email" => from_config_email,
             "urls" => %{
               "streaming_api" => _
             },
             "stats" => _,
             "thumbnail" => from_config_thumbnail,
             "languages" => ["en", "ja"],
             "registrations" => _,
             "approval_required" => _,
             "poll_limits" => _,
             "upload_limit" => _,
             "avatar_upload_limit" => _,
             "background_upload_limit" => _,
             "banner_upload_limit" => _,
             "background_image" => from_config_background,
             "description_limit" => _
           } = result

    assert result["pleroma"]["metadata"]["account_activation_required"] != nil
    assert result["pleroma"]["metadata"]["features"]
    assert result["pleroma"]["metadata"]["federation"]
    assert result["pleroma"]["metadata"]["fields_limits"]
    assert result["pleroma"]["vapid_public_key"]
    assert result["pleroma"]["stats"]["mau"] == 0

    assert email == from_config_email
    assert thumbnail == from_config_thumbnail
    assert background == from_config_background
  end

  test "get instance information prefers WebFinger domain for uri", %{conn: conn} do
    webfinger_domain = "webfinger.example"
    clear_config([Pleroma.Web.WebFinger, :domain], webfinger_domain)
    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)
    assert match?(%{"uri" => ^webfinger_domain}, result)
  end

  test "get instance stats", %{conn: conn} do
    user = insert(:user, %{local: true})

    user2 = insert(:user, %{local: true})
    {:ok, _user2} = User.set_activation(user2, false)

    insert(:user, %{local: false, nickname: "u@peer1.com"})
    insert(:instance, %{domain: "peer1.com"})
    insert(:user, %{local: false, nickname: "u@peer2.com"})
    insert(:instance, %{domain: "peer2.com"})

    {:ok, _} = Pleroma.Web.CommonAPI.post(user, %{status: "cofe"})

    Pleroma.Stats.force_update()

    conn = get(conn, "/api/v1/instance")

    assert result = json_response_and_validate_schema(conn, 200)

    stats = result["stats"]

    assert stats
    assert stats["user_count"] == 1
    assert stats["status_count"] == 1
    assert stats["domain_count"] == 2
  end

  test "get peers", %{conn: conn} do
    insert(:user, %{local: false, nickname: "u@peer1.com"})
    insert(:instance, %{domain: "peer1.com"})
    insert(:user, %{local: false, nickname: "u@peer2.com"})
    insert(:instance, %{domain: "peer2.com"})

    Pleroma.Stats.force_update()

    conn = get(conn, "/api/v1/instance/peers")

    assert result = json_response_and_validate_schema(conn, 200)

    assert ["peer1.com", "peer2.com"] == Enum.sort(result)
  end

  test "get translation languages", %{conn: conn} do
    clear_config([:translator, :enabled], true)

    Tesla.Mock.mock_global(fn
      %{method: :get, url: "https://api-free.deepl.com/v2/languages?type=source"} ->
        %Tesla.Env{
          status: 200,
          body:
            Jason.encode!([
              %{language: "en", name: "English"}
            ])
        }

      %{method: :get, url: "https://api-free.deepl.com/v2/languages?type=target"} ->
        %Tesla.Env{
          status: 200,
          body:
            Jason.encode!([
              %{language: "ja", name: "Japanese"}
            ])
        }
    end)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> get("/api/v1/instance/translation_languages")

    response = json_response_and_validate_schema(conn, 200)

    assert %{"en" => ["ja"]} = response
  end

  test "stubs out translation languages when no translator enabled", %{conn: conn} do
    clear_config([:translator, :enabled], false)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> get("/api/v1/instance/translation_languages")

    response = json_response_and_validate_schema(conn, 200)

    assert %{} == response
  end

  describe "MRF info is" do
    setup %{conn: unauthed_conn} do
      clear_config([:instance, :federating], true)
      clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.SimplePolicy])
      clear_config([:mrf_simple, :reject], [{"bigots.example", "bigottery"}])

      user = insert(:user, local: true)
      %{conn: authed_conn} = oauth_access(["read"], user: user)

      %{authed_conn: authed_conn, unauthed_conn: unauthed_conn}
    end

    test "hides MRF info from authenticated users when transparency disabled", %{
      authed_conn: authed_conn
    } do
      clear_config([:mrf, :transparency], false)

      response =
        authed_conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/instance")
        |> json_response_and_validate_schema(200)

      assert %{"enabled" => true} == response["pleroma"]["metadata"]["federation"]
    end

    test "hides MRF info from anonymous viewers when restricted to authenticated", %{
      unauthed_conn: unauthed_conn
    } do
      clear_config([:mrf, :transparency], :authenticated)

      response =
        unauthed_conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/instance")
        |> json_response_and_validate_schema(200)

      assert %{"enabled" => true} == response["pleroma"]["metadata"]["federation"]
    end

    test "shows MRF info to authenticated users when set to authenticated-only", %{
      authed_conn: authed_conn
    } do
      clear_config([:mrf, :transparency], :authenticated)

      response =
        authed_conn
        |> put_req_header("content-type", "application/json")
        |> get("/api/v1/instance")
        |> json_response_and_validate_schema(200)

      assert %{"mrf_simple" => %{"reject" => ["bigots.example"]}} =
               response["pleroma"]["metadata"]["federation"]
    end
  end
end
