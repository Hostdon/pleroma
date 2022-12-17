# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Activity do
  alias Pleroma.Activity
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Pagination
  require Logger
  import Mix.Pleroma
  import Ecto.Query

  def run(["get", id | _rest]) do
    start_pleroma()

    id
    |> Activity.get_by_id()
    |> IO.inspect()
  end

  def run(["delete_by_keyword", user, keyword | _rest]) do
    start_pleroma()
    u = User.get_by_nickname(user)

    Activity
    |> Activity.with_preloaded_object()
    |> Activity.restrict_deactivated_users()
    |> Activity.Queries.by_author(u)
    |> query_with(keyword)
    |> Pagination.fetch_paginated(
      %{"offset" => 0, "limit" => 20, "skip_order" => false},
      :offset
    )
    |> Enum.map(fn x -> CommonAPI.delete(x.id, u) end)
    |> Enum.count()
    |> IO.puts()
  end

  defp query_with(q, search_query) do
    %{rows: [[tsc]]} =
      Ecto.Adapters.SQL.query!(
        Pleroma.Repo,
        "select current_setting('default_text_search_config')::regconfig::oid;"
      )

    from([a, o] in q,
      where:
        fragment(
          "to_tsvector(?::oid::regconfig, ?->>'content') @@ websearch_to_tsquery(?)",
          ^tsc,
          o.data,
          ^search_query
        )
    )
  end
end
