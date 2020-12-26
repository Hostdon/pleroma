# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.LegacyAuthenticationPlugTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.User
  alias Pleroma.Web.Plugs.LegacyAuthenticationPlug
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.PlugHelper

  setup do
    user =
      insert(:user,
        password: "password",
        password_hash:
          "$6$9psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"
      )

    %{user: user}
  end

  test "it does nothing if a user is assigned", %{conn: conn, user: user} do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "password"})
      |> assign(:auth_user, user)
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

    assert ret_conn == conn
  end

  @tag :skip_on_mac
  test "if `auth_user` is present and password is correct, " <>
         "it authenticates the user, resets the password, marks OAuthScopesPlug as skipped",
       %{
         conn: conn,
         user: user
       } do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "password"})
      |> assign(:auth_user, user)

    conn = LegacyAuthenticationPlug.call(conn, %{})

    assert conn.assigns.user.id == user.id
    assert PlugHelper.plug_skipped?(conn, OAuthScopesPlug)
  end

  @tag :skip_on_mac
  test "it does nothing if the password is wrong", %{
    conn: conn,
    user: user
  } do
    conn =
      conn
      |> assign(:auth_credentials, %{username: "dude", password: "wrong_password"})
      |> assign(:auth_user, user)

    ret_conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

    assert conn == ret_conn
  end

  test "with no credentials or user it does nothing", %{conn: conn} do
    ret_conn =
      conn
      |> LegacyAuthenticationPlug.call(%{})

    assert ret_conn == conn
  end
end
