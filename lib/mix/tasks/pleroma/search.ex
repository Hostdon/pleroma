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

  def run(["import" | _rest]) do
    start_pleroma()

    from(a in Activity, where: not ilike(a.actor, "%/relay"))
    |> Activity.with_preloaded_object()
    |> Activity.with_preloaded_user_actor()
    |> get_all
  end

  defp get_all(query, max_id \\ nil) do
    params = %{limit: 20}

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
      |> Pleroma.Elasticsearch.bulk_post(:activities)

      get_all(query, List.last(res).id)
    end
  end
end
