# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ManifestView do
  use Pleroma.Web, :view
  alias Pleroma.Config
  alias Pleroma.Web.Endpoint

  def render("manifest.json", _params) do
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
        }
      ],
      theme_color: Config.get([:manifest, :theme_color]),
      background_color: Config.get([:manifest, :background_color]),
      display: "standalone",
      scope: Endpoint.url(),
      start_url: "/",
      categories: [
        "social"
      ],
      serviceworker: %{
        src: "/sw-pleroma.js"
      }
    }
  end
end
