# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search do
  use Mix.Task
  import Mix.Pleroma
  import Ecto.Query
  alias Pleroma.Activity
  alias Pleroma.Pagination
  alias Pleroma.User

  @shortdoc "Manages elasticsearch"

  def run(["import", "activities" | _rest]) do
    start_pleroma()

    from(a in Activity, where: not ilike(a.actor, "%/relay"))
    |> where([a], fragment("(? ->> 'type'::text) = 'Create'", a.data))
    |> Activity.with_preloaded_object()
    |> Activity.with_preloaded_user_actor()
    |> get_all(:activities)
  end

  def run(["import", "users" | _rest]) do
    start_pleroma()  
                     
    from(u in User, where: not ilike(u.ap_id, "%/relay"))
    |> get_all(:users)
  end

  defp get_all(query, index, max_id \\ nil) do
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
      |> Pleroma.Elasticsearch.bulk_post(index)

      get_all(query, index, List.last(res).id)
    end
  end
end
