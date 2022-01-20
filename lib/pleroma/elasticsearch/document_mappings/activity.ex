# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Elasticsearch.DocumentMappings.Activity do
  alias Pleroma.Object

  def id(obj), do: obj.id

  def encode(%{object: %{data: %{"type" => "Note"}}} = activity) do
    %{
      _timestamp: activity.inserted_at,
      user: activity.user_actor.nickname,
      content: activity.object.data["content"],
      instance: URI.parse(activity.user_actor.ap_id).host,
      hashtags: Object.hashtags(activity.object)
    }
  end
end
