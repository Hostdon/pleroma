defmodule Pleroma.Search.Elasticsearch do
  @behaviour Pleroma.Search

  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Search.Elasticsearch.Parsers
  alias Pleroma.Web.Endpoint

  def es_query(:activity, query) do
    must = Parsers.Activity.parse(query)

    if must == [] do
      :skip
    else
      %{
        size: 50,
        terminate_after: 50,
        timeout: "5s",
        sort: [
          %{"_timestamp" => "desc"}
        ],
        query: %{
          bool: %{
            must: must
          }
        }
      }
    end
  end

  def es_query(:user, query) do
    must = Parsers.User.parse(query)

    if must == [] do
      :skip
    else
      %{
        size: 50,
        terminate_after: 50,
        timeout: "5s",
        query: %{
          bool: %{
            must: must
          }
        }
      }
    end
  end

  def es_query(:hashtag, query) do
    must = Parsers.Hashtag.parse(query)

    if must == [] do
      :skip
    else
      %{
        size: 50,
        terminate_after: 50,
        timeout: "5s",
        query: %{
          bool: %{
            must: Parsers.Hashtag.parse(query)
          }
        }
      }
    end
  end

  @impl Pleroma.Search
  def search(%{assigns: %{user: user}} = _conn, %{q: query} = _params, _options) do
    parsed_query =
      query
      |> String.trim()
      |> SearchParser.parse!()

    activity_task =
      Task.async(fn ->
        q = es_query(:activity, parsed_query)

        Pleroma.Elasticsearch.search(:activities, q)
        |> Enum.filter(fn x -> Visibility.visible_for_user?(x, user) end)
      end)

    user_task =
      Task.async(fn ->
        q = es_query(:user, parsed_query)

        Pleroma.Elasticsearch.search(:users, q)
        |> Enum.filter(fn x -> Pleroma.User.visible_for(x, user) == :visible end)
      end)

    hashtag_task =
      Task.async(fn ->
        q = es_query(:hashtag, parsed_query)

        Pleroma.Elasticsearch.search(:hashtags, q)
      end)

    activity_results = Task.await(activity_task)
    user_results = Task.await(user_task)
    hashtag_results = Task.await(hashtag_task)

    %{
      "accounts" =>
        AccountView.render("index.json",
          users: user_results,
          for: user
        ),
      "hashtags" =>
        Enum.map(hashtag_results, fn x ->
          %{
            url: Endpoint.url() <> "/tag/" <> x,
            name: x
          }
        end),
      "statuses" =>
        StatusView.render("index.json",
          activities: activity_results,
          for: user,
          as: :activity
        )
    }
  end
end
