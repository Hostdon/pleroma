# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Helpers.AuthHelper do
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  import Plug.Conn

  @doc """
  Skips OAuth permissions (scopes) checks, assigns nil `:token`.
  Intended to be used with explicit authentication and only when OAuth token cannot be determined.
  """
  def skip_oauth(conn) do
    conn
    |> assign(:token, nil)
    |> OAuthScopesPlug.skip_plug()
  end

  @doc "Drops authentication info from connection"
  def drop_auth_info(conn) do
    # To simplify debugging, setting a private variable on `conn` if auth info is dropped
    conn
    |> assign(:user, nil)
    |> assign(:token, nil)
    |> put_private(:authentication_ignored, true)
  end
end
