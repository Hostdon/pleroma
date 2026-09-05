defmodule Pleroma.Web.Plugs.EnsureHostPlugTest do
  use Pleroma.Web.ConnCase, async: false
  alias Pleroma.Web.Plugs.EnsureHostPlug

  import Plug.Conn
  import Mock

  defp put_host_header(conn, host) do
    %{
      conn
      | req_headers: [
          {"host", host} | conn.req_headers
        ]
    }
  end

  describe "requires a host header that matches our server" do
    setup do
      conn = build_conn(:get, "/doesntmatter")

      [conn: conn]
    end

    test "rejects a request where no host value is present", %{conn: conn} do
      conn =
        conn
        |> put_host_header(nil)
        |> EnsureHostPlug.call(%{})

      assert conn.halted == true
      assert conn.status == 400
      assert conn.state == :sent
      assert conn.resp_body == "Host header not present"
    end

    test "rejects a request where the host value does not match", %{conn: conn} do
      conn =
        conn
        |> put_host_header("oops-not-us.info")
        |> EnsureHostPlug.call(%{})

      assert conn.halted == true
      assert conn.status == 400
      assert conn.state == :sent
      assert conn.resp_body == "Host header does not match"
    end

    test "rejects a request where the port value does not match", %{conn: conn} do
      host = Pleroma.Web.Endpoint.host()

      conn =
        conn
        |> put_host_header("#{host}:9")
        |> EnsureHostPlug.call(%{})

      assert conn.halted == true
      assert conn.status == 400
      assert conn.state == :sent
      assert conn.resp_body == "Host header does not match"
    end

    test "accepts a request where the hostname matches and there is no port", %{conn: conn} do
      # this test actually needs a mock as our test server does not run on the default http port

      url = Pleroma.Web.Endpoint.struct_url()

      with_mock Pleroma.Web.Endpoint, struct_url: fn -> %{url | port: 80} end do
        conn =
          conn
          |> put_host_header(url.host)
          |> EnsureHostPlug.call(%{})

        assert conn.halted == false
      end
    end

    test "rejects a request where the hostname matches and there is no port, and we do not run on the default",
         %{conn: conn} do
      url = Pleroma.Web.Endpoint.struct_url()

      conn =
        conn
        |> put_host_header(url.host)
        |> EnsureHostPlug.call(%{})

      assert conn.halted == true
      assert conn.status == 400
      assert conn.state == :sent
      assert conn.resp_body == "Host header does not match"
    end

    test "accepts a request where the hostname matches, with a port", %{conn: conn} do
      %{host: host, port: port} = Pleroma.Web.Endpoint.struct_url()

      conn =
        conn
        |> put_host_header("#{host}:#{port}")
        |> EnsureHostPlug.call(%{})

      assert conn.halted == false
    end

    test "rejects a request with multiple host headers", %{conn: conn} do
      url = Pleroma.Web.Endpoint.struct_url()

      conn =
        conn
        |> put_host_header(url.host)
        |> put_host_header("example.com")
        |> EnsureHostPlug.call(%{})

      assert conn.halted == true
      assert conn.status == 400
      assert conn.state == :sent
      assert conn.resp_body == "Bad host header"
    end
  end
end
