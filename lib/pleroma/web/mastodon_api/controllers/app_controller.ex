# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppController do
  use Pleroma.Web, :controller

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(
    :skip_plug,
    [OAuthScopesPlug, EnsurePublicOrAuthenticatedPlug]
    when action == :create
  )

  plug(OAuthScopesPlug, %{scopes: ["read"]} when action == :verify_credentials)

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  @local_mastodon_name "Mastodon-Local"

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.AppOperation

  @doc "POST /api/v1/apps"
  def create(%{body_params: params} = conn, _params) do
    scopes = Scopes.fetch_scopes(params, ["read"])

    app_attrs =
      params
      |> Map.take([:client_name, :redirect_uris, :website])
      |> Map.put(:scopes, scopes)

    with cs <- App.register_changeset(%App{}, app_attrs),
         false <- cs.changes[:client_name] == @local_mastodon_name,
         {:ok, app} <- Repo.insert(cs) do
      render(conn, "show.json", app: app)
    end
  end

  @doc "GET /api/v1/apps/verify_credentials"
  def verify_credentials(%{assigns: %{user: _user, token: token}} = conn, _) do
    with %Token{app: %App{} = app} <- Repo.preload(token, :app) do
      render(conn, "short.json", app: app)
    end
  end
end
