# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppView do
  use Pleroma.Web, :view

  alias Pleroma.Web.OAuth.App

  def render("index.json", %{apps: apps, count: count, page_size: page_size, admin: true}) do
    %{
      apps: render_many(apps, Pleroma.Web.MastodonAPI.AppView, "show.json", %{admin: true}),
      count: count,
      page_size: page_size
    }
  end

  def render("show.json", %{admin: true, app: %App{} = app} = assigns) do
    "show.json"
    |> render(Map.delete(assigns, :admin))
    |> Map.put(:trusted, app.trusted)
    |> Map.put(:id, app.id)
  end

  def render("show.json", %{app: %App{} = app}) do
    %{
      id: app.id |> to_string,
      name: app.client_name,
      client_id: app.client_id,
      client_secret: app.client_secret,
      redirect_uri: app.redirect_uris,
      website: app.website
    }
    |> with_vapid_key()
  end

  def render("short.json", %{app: %App{website: webiste, client_name: name}}) do
    %{
      name: name,
      website: webiste
    }
    |> with_vapid_key()
  end

  defp with_vapid_key(data) do
    vapid_key = Application.get_env(:web_push_encryption, :vapid_details, [])[:public_key]

    Pleroma.Maps.put_if_present(data, "vapid_key", vapid_key)
  end
end
