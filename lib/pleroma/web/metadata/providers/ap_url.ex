# Akkoma: Magically expressive social media
# Copyright © 2025 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.ApUrl do
  alias Pleroma.Web.Metadata.Providers.Provider

  @behaviour Provider

  defp alt_link(uri, type) do
    {
      :link,
      [rel: "alternate", href: uri, type: type],
      []
    }
  end

  defp ap_alt_links(uri) do
    [
      alt_link(uri, "application/activity+json"),
      alt_link(uri, "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"")
    ]
  end

  @impl Provider
  def build_tags(%{object: %{data: %{"id" => ap_id}}}) when is_binary(ap_id) do
    ap_alt_links(ap_id)
  end

  def build_tags(%{user: %{ap_id: ap_id}}) when is_binary(ap_id) do
    ap_alt_links(ap_id)
  end

  def build_tags(_), do: []
end
