# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NormalizeMarkup do
  @moduledoc "Scrub configured hypertext markup"
  alias Pleroma.HTML

  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @impl true
  def history_awareness, do: :auto

  def scrub_if_present(obj, field, scrubber) do
    case obj[field] do
      text when is_binary(text) ->
        update_in(obj[field], &HTML.filter_tags(&1, scrubber))

      map when is_map(map) ->
        map =
          Enum.into(map, %{}, fn
            {k, v} when is_binary(v) ->
              {k, HTML.filter_tags(v, scrubber)}

            {k, v} ->
              {k, v}
          end)

        put_in(obj[field], map)

      _ ->
        obj
    end
  end

  @impl true
  def filter(%{"type" => type, "object" => child_object} = object)
      when type in ["Create", "Update"] do
    scrub_policy = Pleroma.Config.get([:mrf_normalize_markup, :scrub_policy])

    child_object =
      child_object
      |> scrub_if_present("content", scrub_policy)
      |> scrub_if_present("contentMap", scrub_policy)

    object = put_in(object["object"], child_object)
    {:ok, object}
  end

  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}

  @impl true
  def config_description do
    %{
      key: :mrf_normalize_markup,
      related_policy: "Pleroma.Web.ActivityPub.MRF.NormalizeMarkup",
      label: "MRF Normalize Markup",
      description: "MRF NormalizeMarkup settings. Scrub configured hypertext markup.",
      children: [
        %{
          key: :scrub_policy,
          type: :module,
          suggestions: [Pleroma.HTML.Scrubber.Default]
        }
      ]
    }
  end
end
