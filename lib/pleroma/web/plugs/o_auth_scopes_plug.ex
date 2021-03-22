# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.OAuthScopesPlug do
  import Plug.Conn
  import Pleroma.Web.Gettext

  alias Pleroma.Config

  use Pleroma.Web, :plug

  def init(%{scopes: _} = options), do: options

  @impl true
  def perform(%Plug.Conn{assigns: assigns} = conn, %{scopes: scopes} = options) do
    op = options[:op] || :|
    token = assigns[:token]

    scopes = transform_scopes(scopes, options)
    matched_scopes = (token && filter_descendants(scopes, token.scopes)) || []

    cond do
      token && op == :| && Enum.any?(matched_scopes) ->
        conn

      token && op == :& && matched_scopes == scopes ->
        conn

      options[:fallback] == :proceed_unauthenticated ->
        drop_auth_info(conn)

      true ->
        missing_scopes = scopes -- matched_scopes
        permissions = Enum.join(missing_scopes, " #{op} ")

        error_message =
          dgettext("errors", "Insufficient permissions: %{permissions}.", permissions: permissions)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(:forbidden, Jason.encode!(%{error: error_message}))
        |> halt()
    end
  end

  @doc "Drops authentication info from connection"
  def drop_auth_info(conn) do
    # To simplify debugging, setting a private variable on `conn` if auth info is dropped
    conn
    |> put_private(:authentication_ignored, true)
    |> assign(:user, nil)
    |> assign(:token, nil)
  end

  @doc "Keeps those of `scopes` which are descendants of `supported_scopes`"
  def filter_descendants(scopes, supported_scopes) do
    Enum.filter(
      scopes,
      fn scope ->
        Enum.find(
          supported_scopes,
          &(scope == &1 || String.starts_with?(scope, &1 <> ":"))
        )
      end
    )
  end

  @doc "Transforms scopes by applying supported options (e.g. :admin)"
  def transform_scopes(scopes, options) do
    if options[:admin] do
      Config.oauth_admin_scopes(scopes)
    else
      scopes
    end
  end
end
