# Akkoma: Magically expressive social media
# Copyright Â© 2022-2022 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureHTTPSignaturePlugTest do
  use Pleroma.Web.ConnCase, async: false
  alias Pleroma.Web.Plugs.EnsureHTTPSignaturePlug

  import Plug.Conn
  import Phoenix.Controller, only: [put_format: 2]

  import Pleroma.Tests.Helpers, only: [clear_config: 2]

  describe "requires a signature when `authorized_fetch_mode` is enabled" do
    setup do
      clear_config([:activitypub, :authorized_fetch_mode], true)

      conn =
        build_conn(:get, "/doesntmatter")
        |> put_format("activity+json")

      [conn: conn]
    end

    test "and signature has been set as invalid", %{conn: conn} do
      conn =
        conn
        |> assign(:valid_signature, false)
        |> EnsureHTTPSignaturePlug.call(%{})

      assert conn.halted == true
      assert conn.status == 401
      assert conn.state == :sent
      assert conn.resp_body == "Request not signed"
    end

    test "and signature has been set as valid", %{conn: conn} do
      conn =
        conn
        |> assign(:valid_signature, true)
        |> EnsureHTTPSignaturePlug.call(%{})

      assert conn.halted == false
    end

    test "does nothing for non-ActivityPub content types", %{conn: conn} do
      conn =
        conn
        |> assign(:valid_signature, false)
        |> put_format("html")
        |> EnsureHTTPSignaturePlug.call(%{})

      assert conn.halted == false
    end
  end

  test "does nothing on invalid signature when `authorized_fetch_mode` is disabled" do
    clear_config([:activitypub, :authorized_fetch_mode], false)

    conn =
      build_conn(:get, "/doesntmatter")
      |> put_format("activity+json")
      |> assign(:valid_signature, false)
      |> EnsureHTTPSignaturePlug.call(%{})

    assert conn.halted == false
  end
end
