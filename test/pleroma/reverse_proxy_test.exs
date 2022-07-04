# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxyTest do
  use Pleroma.Web.ConnCase
  import ExUnit.CaptureLog

  alias Pleroma.ReverseProxy
  alias Plug.Conn

  describe "reverse proxy" do
    test "do not track successful request", %{conn: conn} do
      url = "/success"

      Tesla.Mock.mock(fn %{url: ^url} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }
      end)

      conn = ReverseProxy.call(conn, url)

      assert response(conn, 200)
      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, nil}
    end

    test "use Pleroma's user agent in the request; don't pass the client's", %{conn: conn} do
      clear_config([:http, :send_user_agent], true)
      # Mock will fail if the client's user agent isn't filtered
      wanted_headers = [{"user-agent", Pleroma.Application.user_agent()}]

      Tesla.Mock.mock(fn %{url: "/user-agent", headers: ^wanted_headers} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }
      end)

      conn =
        conn
        |> Plug.Conn.put_req_header("user-agent", "fake/1.0")
        |> ReverseProxy.call("/user-agent")

      assert response(conn, 200)
    end
  end

  describe "max_body" do
    test "length returns error if content-length more than option", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "/huge-file"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-length", "100"}],
          body: "This body is too large."
        }
      end)

      assert capture_log(fn ->
               ReverseProxy.call(conn, "/huge-file", max_body_length: 4)
             end) =~
               "[error] Elixir.Pleroma.ReverseProxy: request to \"/huge-file\" failed: :body_too_large"

      assert {:ok, true} == Cachex.get(:failed_proxy_url_cache, "/huge-file")

      assert capture_log(fn ->
               ReverseProxy.call(conn, "/huge-file", max_body_length: 4)
             end) == ""
    end
  end

  describe "HEAD requests" do
    test "common", %{conn: conn} do
      Tesla.Mock.mock(fn %{method: :head, url: "/head"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "text/html; charset=utf-8"}],
          body: ""
        }
      end)

      conn = ReverseProxy.call(Map.put(conn, :method, "HEAD"), "/head")
      assert html_response(conn, 200) == ""
    end
  end

  describe "returns error on" do
    test "500", %{conn: conn} do
      url = "/status/500"

      Tesla.Mock.mock(fn %{url: ^url} ->
        %Tesla.Env{
          status: 500,
          body: ""
        }
      end)

      capture_log(fn -> ReverseProxy.call(conn, url) end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/500 failed with HTTP status 500"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}

      {:ok, ttl} = Cachex.ttl(:failed_proxy_url_cache, url)
      assert ttl <= 60_000
    end

    test "400", %{conn: conn} do
      url = "/status/400"

      Tesla.Mock.mock(fn %{url: ^url} ->
        %Tesla.Env{
          status: 400,
          body: ""
        }
      end)

      capture_log(fn -> ReverseProxy.call(conn, url) end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/400 failed with HTTP status 400"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}
      assert Cachex.ttl(:failed_proxy_url_cache, url) == {:ok, nil}
    end

    test "403", %{conn: conn} do
      url = "/status/403"

      Tesla.Mock.mock(fn %{url: ^url} ->
        %Tesla.Env{
          status: 403,
          body: ""
        }
      end)

      capture_log(fn ->
        ReverseProxy.call(conn, url, failed_request_ttl: :timer.seconds(120))
      end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/403 failed with HTTP status 403"

      {:ok, ttl} = Cachex.ttl(:failed_proxy_url_cache, url)
      assert ttl > 100_000
    end
  end

  describe "keep request headers" do
    test "header passes", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "/headers"} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }
      end)

      conn =
        Conn.put_req_header(
          conn,
          "accept",
          "text/html"
        )
        |> ReverseProxy.call("/headers")

      assert response(conn, 200)
      assert {"accept", "text/html"} in conn.req_headers
    end

    test "header is filtered", %{conn: conn} do
      # Mock will fail if the accept-language header isn't filtered
      wanted_headers = [{"accept-encoding", "*"}]

      Tesla.Mock.mock(fn %{url: "/headers", headers: ^wanted_headers} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }
      end)

      conn =
        conn
        |> Conn.put_req_header("accept-language", "en-US")
        |> Conn.put_req_header("accept-encoding", "*")
        |> ReverseProxy.call("/headers")

      assert response(conn, 200)
    end
  end

  test "returns 400 on non GET, HEAD requests", %{conn: conn} do
    Tesla.Mock.mock(fn %{url: "/ip"} ->
      %Tesla.Env{
        status: 200,
        body: ""
      }
    end)

    conn = ReverseProxy.call(Map.put(conn, :method, "POST"), "/ip")
    assert response(conn, 400)
  end

  describe "cache resp headers not filtered" do
    test "add cache-control", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "/cache"} ->
        %Tesla.Env{
          status: 200,
          headers: [
            {"cache-control", "public, max-age=1209600"},
            {"etag", "some ETag"},
            {"expires", "Wed, 21 Oct 2015 07:28:00 GMT"}
          ],
          body: ""
        }
      end)

      conn = ReverseProxy.call(conn, "/cache")
      assert {"cache-control", "public, max-age=1209600"} in conn.resp_headers
      assert {"etag", "some ETag"} in conn.resp_headers
      assert {"expires", "Wed, 21 Oct 2015 07:28:00 GMT"} in conn.resp_headers
    end
  end

  describe "response content disposition header" do
    test "not attachment", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "/disposition"} ->
        %Tesla.Env{
          status: 200,
          headers: [
            {"content-type", "image/gif"},
            {"content-length", "0"}
          ],
          body: ""
        }
      end)

      conn = ReverseProxy.call(conn, "/disposition")

      assert {"content-type", "image/gif"} in conn.resp_headers
    end

    test "with content-disposition header", %{conn: conn} do
      Tesla.Mock.mock(fn %{url: "/disposition"} ->
        %Tesla.Env{
          status: 200,
          headers: [
            {"content-disposition", "attachment; filename=\"filename.jpg\""},
            {"content-length", "0"}
          ],
          body: ""
        }
      end)

      conn = ReverseProxy.call(conn, "/disposition")

      assert {"content-disposition", "attachment; filename=\"filename.jpg\""} in conn.resp_headers
    end
  end
end
