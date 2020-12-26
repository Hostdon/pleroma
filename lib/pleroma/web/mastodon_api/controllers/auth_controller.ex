# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AuthController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [json_response: 3]

  alias Pleroma.User
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.TwitterAPI.TwitterAPI

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(Pleroma.Web.Plugs.RateLimiter, [name: :password_reset] when action == :password_reset)

  @local_mastodon_name "Mastodon-Local"

  @doc "GET /web/login"
  def login(%{assigns: %{user: %User{}}} = conn, _params) do
    redirect(conn, to: local_mastodon_root_path(conn))
  end

  # Local Mastodon FE login init action
  def login(conn, %{"code" => auth_token}) do
    with {:ok, app} <- get_or_make_app(),
         {:ok, auth} <- Authorization.get_by_token(app, auth_token),
         {:ok, token} <- Token.exchange_token(app, auth) do
      conn
      |> put_session(:oauth_token, token.token)
      |> redirect(to: local_mastodon_root_path(conn))
    end
  end

  # Local Mastodon FE callback action
  def login(conn, _) do
    with {:ok, app} <- get_or_make_app() do
      path =
        o_auth_path(conn, :authorize,
          response_type: "code",
          client_id: app.client_id,
          redirect_uri: ".",
          scope: Enum.join(app.scopes, " ")
        )

      redirect(conn, to: path)
    end
  end

  @doc "DELETE /auth/sign_out"
  def logout(conn, _) do
    conn
    |> clear_session
    |> redirect(to: "/")
  end

  @doc "POST /auth/password"
  def password_reset(conn, params) do
    nickname_or_email = params["email"] || params["nickname"]

    TwitterAPI.password_reset(nickname_or_email)

    json_response(conn, :no_content, "")
  end

  defp local_mastodon_root_path(conn) do
    case get_session(conn, :return_to) do
      nil ->
        masto_fe_path(conn, :index, ["getting-started"])

      return_to ->
        delete_session(conn, :return_to)
        return_to
    end
  end

  @spec get_or_make_app() :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  defp get_or_make_app do
    %{client_name: @local_mastodon_name, redirect_uris: "."}
    |> App.get_or_make(["read", "write", "follow", "push", "admin"])
  end
end
