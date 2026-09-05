# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ManifestView do
  use Pleroma.Web, :view
  alias Pleroma.Config
  alias Pleroma.Web.Endpoint

  def render("manifest.json", params) do
    user_overrides = Config.get([:manifest], []) |> Enum.into(%{})

    api_overrides =
      params[:api_manifest_overrides] ||
        %{start_url: "/", serviceworker: %{src: "/sw-pleroma.js"}}

    %{
      name: Config.get([:instance, :name]),
      description: Config.get([:instance, :description]),
      icons: [
        %{
          src: "/static/logo.svg",
          type: "image/svg+xml"
        },
        %{
          src: "/static/logo-512.png",
          sizes: "512x512",
          type: "image/png",
          purpose: "maskable"
        },
        %{
          src: "/static/logo-512.png",
          sizes: "512x512",
          type: "image/png"
        }
      ],
      theme_color: "#282c37",
      background_color: "#191b22",
      display: "standalone",
      scope: Endpoint.url(),
      categories: [
        "social"
      ]
    }
    |> Map.merge(user_overrides)
    |> Map.merge(api_overrides)
  end
end
