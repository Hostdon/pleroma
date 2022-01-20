# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.Elasticsearch do
  @behaviour Pleroma.Search

  alias Pleroma.Activity
  alias Pleroma.Object.Fetcher
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
          "_score",
          %{_timestamp: %{order: "desc", format: "basic_date_time"}}
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
        sort: [
          "_score"
        ],
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
        sort: [
          "_score"
        ],
        query: %{
          bool: %{
            must: Parsers.Hashtag.parse(query)
          }
        }
      }
    end
  end

  defp maybe_fetch(:activity, search_query) do
    with true <- Regex.match?(~r/https?:/, search_query),
         {:ok, object} <- Fetcher.fetch_object_from_id(search_query),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]) do
      activity
    else
      _ -> nil
    end
  end

  @impl Pleroma.Search
  def search(%{assigns: %{user: user}} = _conn, %{q: query} = _params, _options) do
    parsed_query =
      query
      |> String.trim()
      |> SearchParser.parse!()

    activity_fetch_task =
      Task.async(fn ->
        maybe_fetch(:activity, String.trim(query))
      end)

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
    direct_activity = Task.await(activity_fetch_task)

    activity_results =
      if direct_activity == nil do
        activity_results
      else
        [direct_activity | activity_results]
      end

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
