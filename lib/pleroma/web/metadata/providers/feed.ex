# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.Feed do
  alias Pleroma.Web.Metadata.Providers.Provider

  use Pleroma.Web, :verified_routes

  @behaviour Provider

  @impl Provider
  def build_tags(%{user: user}) do
    [
      {:link,
       [
         rel: "alternate",
         type: "application/atom+xml",
         href: ~p[/users/#{user.nickname}/feed.atom]
       ], []}
    ]
  end
end
