# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy do
  @moduledoc "Force a quote line into the message content."
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.Object

  defp build_inline_quote(prefix, url) do
    "<span class=\"quote-inline\"><br/><br/>#{prefix}: <a href=\"#{url}\">#{url}</a></span>"
  end

  defp resolve_urls(quote_url) do
    # Fetching here can cause infinite recursion as we run this logic on inbound objects too
    # This is probably not a problem - its an exceptional corner case for a local user to quote
    # a post which doesn't exist
    with %Object{} = obj <- Object.normalize(quote_url, fetch: false) do
      id = obj.data["id"]
      url = Map.get(obj.data, "url", id)
      {id, url, [id, url, quote_url]}
    else
      _ -> {quote_url, quote_url, [quote_url]}
    end
  end

  defp has_inline_quote?(content, urls) do
    cond do
      # Does the quote URL exist in the content?
      Enum.any?(urls, fn url -> content =~ url end) -> true
      # Does the content already have a .quote-inline span?
      content =~ "<span class=\"quote-inline\">" -> true
      # No inline quote found
      true -> false
    end
  end

  defp filter_object(%{"quoteUri" => quote_url} = object) do
    {id, preferred_url, all_urls} = resolve_urls(quote_url)
    object = Map.put(object, "quoteUri", id)

    content = object["content"] || ""

    if has_inline_quote?(content, all_urls) do
      object
    else
      prefix = Pleroma.Config.get([:mrf_inline_quote, :prefix])

      content =
        if String.ends_with?(content, "</p>") do
          String.trim_trailing(content, "</p>") <>
            build_inline_quote(prefix, preferred_url) <> "</p>"
        else
          content <> build_inline_quote(prefix, preferred_url)
        end

      Map.put(object, "content", content)
    end
  end

  @impl true
  def filter(%{"object" => %{"quoteUri" => _} = object} = activity) do
    {:ok, Map.put(activity, "object", filter_object(object))}
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_inline_quote,
      related_policy: "Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy",
      label: "MRF Inline Quote",
      description: "Force quote post URLs inline",
      children: [
        %{
          key: :prefix,
          type: :string,
          description: "Prefix before the link",
          suggestions: ["RE", "QT", "RT", "RN"]
        }
      ]
    }
  end
end
