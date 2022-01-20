# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.Elasticsearch.Parsers.Activity do
  defp to_es(term) when is_binary(term) do
    %{
      match: %{
        content: %{
          query: term,
          operator: "AND"
        }
      }
    }
  end

  defp to_es({:quoted, term}), do: to_es(term)

  defp to_es({:filter, ["hashtag", query]}) do
    %{
      term: %{
        hashtags: %{
          value: query
        }
      }
    }
  end

  defp to_es({:filter, [field, query]}) do
    %{
      term: %{
        field => %{
          value: query
        }
      }
    }
  end

  def parse(q) do
    Enum.map(q, &to_es/1)
  end
end
