# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SearchController do
  use Pleroma.Web, :controller

  alias Pleroma.User
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter

  require Logger

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  # Note: Mastodon doesn't allow unauthenticated access (requires read:accounts / read:search)
  plug(OAuthScopesPlug, %{scopes: ["read:search"], fallback: :proceed_unauthenticated})

  # Note: on private instances auth is required (EnsurePublicOrAuthenticatedPlug is not skipped)

  plug(RateLimiter, [name: :search] when action in [:search, :search2, :account_search])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.SearchOperation

  def account_search(%{assigns: %{user: user}} = conn, %{q: query} = params) do
    accounts = User.search(query, search_options(params, user))

    conn
    |> put_view(AccountView)
    |> render("index.json",
      users: accounts,
      for: user,
      as: :user
    )
  end

  def search2(conn, params), do: do_search(:v2, conn, params)
  def search(conn, params), do: do_search(:v1, conn, params)

  defp do_search(version, %{assigns: %{user: user}} = conn, params) do
    options =
      search_options(params, user)
      |> Keyword.put(:version, version)

    search_provider = Pleroma.Config.get([:search, :provider])
    json(conn, search_provider.search(conn, params, options))
  end

  defp search_options(params, user) do
    [
      resolve: params[:resolve],
      following: params[:following],
      limit: params[:limit],
      offset: params[:offset],
      type: params[:type],
      author: get_author(params),
      embed_relationships: ControllerHelper.embed_relationships?(params),
      for_user: user
    ]
    |> Enum.filter(&elem(&1, 1))
  end

  defp get_author(%{account_id: account_id}) when is_binary(account_id),
    do: User.get_cached_by_id(account_id)

  defp get_author(_params), do: nil
end
