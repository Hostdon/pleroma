# Akkoma: The cooler fediverse server
# Copyright © 2022- Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Akkoma.Collections.Fetcher do
  @moduledoc """
  Activitypub Collections fetching functions
  see: https://www.w3.org/TR/activitystreams-core/#paging
  """
  alias Pleroma.Object.Fetcher
  alias Pleroma.Config

  def fetch_collection_by_ap_id(ap_id) when is_binary(ap_id) do
    fetch_collection(ap_id)
  end

  defp fetch_collection(ap_id) do
    with {:ok, page} <- Fetcher.fetch_and_contain_remote_object_from_id(ap_id) do
      {:ok, objects_from_collection(page)}
    end
  end

  defp items_in_page(%{"type" => type, "orderedItems" => items})
       when is_list(items) and type in ["OrderedCollection", "OrderedCollectionPage"],
       do: items

  defp items_in_page(%{"type" => type, "items" => items})
       when is_list(items) and type in ["Collection", "CollectionPage"],
       do: items

  defp objects_from_collection(%{"type" => "OrderedCollection", "orderedItems" => items})
       when is_list(items),
       do: items

  defp objects_from_collection(%{"type" => "Collection", "items" => items}) when is_list(items),
    do: items

  defp objects_from_collection(%{"type" => type, "first" => first})
       when is_binary(first) and type in ["Collection", "OrderedCollection"] do
    fetch_page_items(first)
  end

  defp objects_from_collection(%{"type" => type, "first" => %{"id" => id}})
       when is_binary(id) and type in ["Collection", "OrderedCollection"] do
    fetch_page_items(id)
  end

  defp fetch_page_items(id, items \\ []) do
    if Enum.count(items) >= Config.get([:activitypub, :max_collection_objects]) do
      items
    else
      {:ok, page} = Fetcher.fetch_and_contain_remote_object_from_id(id)
      objects = items_in_page(page)

      if Enum.count(objects) > 0 do
        maybe_next_page(page, items ++ objects)
      else
        items
      end
    end
  end

  defp maybe_next_page(%{"next" => id}, items) when is_binary(id) do
    fetch_page_items(id, items)
  end

  defp maybe_next_page(_, items), do: items
end
