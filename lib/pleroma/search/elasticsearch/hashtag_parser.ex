# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.Elasticsearch.Parsers.Hashtag do
  defp to_es(term) when is_binary(term) do
    %{
      term: %{
        hashtag: %{
          value: String.downcase(term)
        }
      }
    }
  end

  defp to_es({:quoted, term}), do: to_es(term)

  defp to_es({:filter, ["hashtag", query]}) do
    %{
      term: %{
        hashtag: %{
          value: String.downcase(query)
        }
      }
    }
  end

  defp to_es({:filter, _}), do: nil

  def parse(q) do
    Enum.map(q, &to_es/1)
    |> Enum.filter(fn x -> x != nil end)
  end
end
