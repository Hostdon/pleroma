defmodule Pleroma.Search.Elasticsearch do
  @behaviour Pleroma.Search

  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.ActivityPub.Visibility

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

  defp parse(query) do
    query
    |> SearchParser.parse!()
    |> Enum.map(&to_es/1)
  end

  @impl Pleroma.Search
  def search(%{assigns: %{user: user}} = _conn, %{q: query} = _params, _options) do
    q = %{
      query: %{
        bool: %{
          must: parse(query)
        }
      }
    }

    out = Pleroma.Elasticsearch.search_activities(q)

    with {:ok, raw_results} <- out do
      results =
        raw_results
        |> Map.get(:body, %{})
        |> Map.get("hits", %{})
        |> Map.get("hits", [])
        |> Enum.map(fn result -> result["_id"] end)
        |> Pleroma.Activity.all_by_ids_with_object()
	|> Enum.filter(fn x -> Visibility.visible_for_user?(x, user) end)

      %{
        "accounts" => [],
        "hashtags" => [],
        "statuses" =>
          StatusView.render("index.json",
            activities: results,
            for: user,
            as: :activity
          )
      }
    end
  end
end
