# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFinger.WebFingerControllerTest do
  use Pleroma.Web.ConnCase

  import ExUnit.CaptureLog
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup_all do: clear_config([:instance, :federating], true)

  test "GET host-meta" do
    response =
      build_conn()
      |> get("/.well-known/host-meta")

    assert response.status == 200

    assert response.resp_body ==
             ~s(<?xml version="1.0" encoding="UTF-8"?><XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0"><Link rel="lrdd" template="#{
               Pleroma.Web.Endpoint.url()
             }/.well-known/webfinger?resource={uri}" type="application/xrd+xml" /></XRD>)
  end

  test "Webfinger JRD" do
    user =
      insert(:user,
        ap_id: "https://hyrule.world/users/zelda",
        also_known_as: ["https://mushroom.kingdom/users/toad"]
      )

    response =
      build_conn()
      |> put_req_header("accept", "application/jrd+json")
      |> get("/.well-known/webfinger?resource=acct:#{user.nickname}@localhost")
      |> json_response(200)

    assert response["subject"] == "acct:#{user.nickname}@localhost"

    assert response["aliases"] == [
             "https://hyrule.world/users/zelda",
             "https://mushroom.kingdom/users/toad"
           ]
  end

  test "it returns 404 when user isn't found (JSON)" do
    result =
      build_conn()
      |> put_req_header("accept", "application/jrd+json")
      |> get("/.well-known/webfinger?resource=acct:jimm@localhost")
      |> json_response(404)

    assert result == "Couldn't find user"
  end

  test "Webfinger XML" do
    user =
      insert(:user,
        ap_id: "https://hyrule.world/users/zelda",
        also_known_as: ["https://mushroom.kingdom/users/toad"]
      )

    response =
      build_conn()
      |> put_req_header("accept", "application/xrd+xml")
      |> get("/.well-known/webfinger?resource=acct:#{user.nickname}@localhost")
      |> response(200)

    assert response =~ "<Alias>https://hyrule.world/users/zelda</Alias>"
    assert response =~ "<Alias>https://mushroom.kingdom/users/toad</Alias>"
  end

  test "it returns 404 when user isn't found (XML)" do
    result =
      build_conn()
      |> put_req_header("accept", "application/xrd+xml")
      |> get("/.well-known/webfinger?resource=acct:jimm@localhost")
      |> response(404)

    assert result == "Couldn't find user"
  end

  test "Sends a 404 when invalid format" do
    user = insert(:user)

    assert capture_log(fn ->
             assert_raise Phoenix.NotAcceptableError, fn ->
               build_conn()
               |> put_req_header("accept", "text/html")
               |> get("/.well-known/webfinger?resource=acct:#{user.nickname}@localhost")
             end
           end) =~ "no supported media type in accept header"
  end

  test "Sends a 400 when resource param is missing" do
    response =
      build_conn()
      |> put_req_header("accept", "application/xrd+xml,application/jrd+json")
      |> get("/.well-known/webfinger")

    assert response(response, 400)
  end
end
