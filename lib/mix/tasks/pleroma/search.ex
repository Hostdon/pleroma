# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search do
  use Mix.Task
  import Mix.Pleroma
  import Ecto.Query
  alias Pleroma.Activity
  alias Pleroma.Pagination

  @shortdoc "Manages elasticsearch"

  def run(["import_since", d | _rest]) do
    start_pleroma()
    {:ok, since, _} = DateTime.from_iso8601(d)

    from(a in Activity, where: not ilike(a.actor, "%/relay") and a.inserted_at > ^since)
    |> Activity.with_preloaded_object()
    |> Activity.with_preloaded_user_actor()
    |> get_all
  end

  def run(["import" | _rest]) do
    start_pleroma()

    from(a in Activity, where: not ilike(a.actor, "%/relay"))
    |> where([a], fragment("(? ->> 'type'::text) = 'Create'", a.data))
    |> Activity.with_preloaded_object()
    |> Activity.with_preloaded_user_actor()
    |> get_all
  end

  defp get_all(query, max_id \\ nil) do
    IO.puts(max_id)
    params = %{limit: 2000}

    params =
      if max_id == nil do
        params
      else
        Map.put(params, :max_id, max_id)
      end

    res =
      query
      |> Pagination.fetch_paginated(params)

    if res == [] do
      :ok
    else
      res
      |> Enum.filter(fn x ->
        t =
          x.object
          |> Map.get(:data, %{})
          |> Map.get("type", "")

        t == "Note"
      end)
      |> Pleroma.Elasticsearch.bulk_post(:activities)

      get_all(query, List.last(res).id)
    end
  end
end
