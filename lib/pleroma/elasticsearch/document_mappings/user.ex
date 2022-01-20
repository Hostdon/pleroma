# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Elasticsearch.DocumentMappings.User do
  def id(obj), do: obj.id

  def encode(%{actor_type: "Person"} = user) do
    %{
      timestamp: user.inserted_at,
      instance: URI.parse(user.ap_id).host,
      nickname: user.nickname,
      bio: user.bio,
      display_name: user.name
    }
  end
end
