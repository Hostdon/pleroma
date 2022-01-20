# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Elasticsearch.DocumentMappings.Hashtag do
  def id(obj), do: obj.id

  def encode(%{timestamp: _} = hashtag) do
    %{
      hashtag: hashtag.name,
      timestamp: hashtag.timestamp
    }
  end

  def encode(hashtag) do
    %{
      hashtag: hashtag.name,
      timestamp: hashtag.inserted_at
    }
  end
end
