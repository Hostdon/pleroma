# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.Elasticsearch do
  @behaviour Pleroma.Search.SearchBackend

  alias Pleroma.Activity
  alias Pleroma.Object.Fetcher
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Search.Elasticsearch.Parsers

  require Logger

  def es_query(:activity, query, offset, limit) do
    must = Parsers.Activity.parse(query)

    %{
      size: limit,
      from: offset,
      terminate_after: 50,
      timeout: "5s",
      sort: [
        "_score",
        %{"_timestamp" => %{order: "desc", format: "basic_date_time"}}
      ],
      query: %{
        bool: %{
          must: must
        }
      }
    }
  end

  defp maybe_fetch(:activity, search_query, options) do
    with true <- options[:resolve],
         0 <- Keyword.get(options, :offset, 0),
         true <- Regex.match?(~r/https?:/, search_query),
         {:ok, object} <- Fetcher.fetch_object_from_id(search_query),
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]) do
      activity
    else
      _ -> nil
    end
  end

  defp await_fetch_task(task) do
    # Multiplier for following redirect and id mismatch refetch (without redirect)
    timeout = 3 * Pleroma.Config.get!([:http, :receive_timeout])

    case Task.yield(task, timeout) || Task.shutdown(task, 250) do
      {:ok, result} ->
        result

      {:exit, reason} ->
        Logger.debug("Search fetch task exited: #{inspect(reason)}")
        nil

      nil ->
        Logger.debug("Search fetch task timed out after #{timeout}ms")
        nil
    end
  end

  def search(user, query, options) do
    limit = Enum.min([Keyword.get(options, :limit), 40])
    offset = Keyword.get(options, :offset, 0)

    parsed_query =
      query
      |> String.trim()
      |> SearchParser.parse!()

    activity_fetch_task =
      Task.async(fn ->
        maybe_fetch(:activity, String.trim(query), options)
      end)

    activity_task =
      Task.async(fn ->
        q = es_query(:activity, parsed_query, offset, limit)

        :activities
        |> Pleroma.Search.Elasticsearch.Store.search(q)
        |> Enum.filter(fn x ->
          x.data["type"] == "Create" && x.object.data["type"] == "Note" &&
            Visibility.visible_for_user?(x, user)
        end)
      end)

    activity_results = Task.await(activity_task)
    direct_activity = await_fetch_task(activity_fetch_task)

    activity_results =
      if direct_activity == nil do
        activity_results
      else
        [direct_activity | activity_results]
      end

    activity_results
  end

  @impl true
  def add_to_index(activity) do
    Elasticsearch.put_document(Pleroma.Search.Elasticsearch.Cluster, activity, "activities")
  end

  @impl true
  def remove_from_index(object) do
    Elasticsearch.delete_document(Pleroma.Search.Elasticsearch.Cluster, object, "activities")
  end
end
