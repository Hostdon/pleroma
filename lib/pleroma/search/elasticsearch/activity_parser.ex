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
