# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.DatabaseSearch do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Visibility

  require Pleroma.Constants

  import Ecto.Query

  @behaviour Pleroma.Search.SearchBackend

  def search(user, search_query, options \\ []) do
    maybe_network = should_resolve_remote(options) && is_uri(search_query)
    action = fn -> do_search(user, search_query, options) end

    # We want to checkout a connection to not be stuck repeatedly in queue
    # but not needlessly stall other queries while we wait for a network response
    if !maybe_network do
      Repo.checkout(action)
    else
      action.()
    end
  end

  defp is_uri("https://" <> _), do: true
  defp is_uri("http://" <> _), do: true
  defp is_uri(_), do: false

  defp should_resolve_remote(options) do
    options[:resolve] && Keyword.get(options, :offset, 0) == 0
  end

  defp do_search(user, search_query, options) do
    apid_match = is_uri(search_query) && maybe_locate_apid(search_query, user, options)

    if apid_match do
      [apid_match]
    else
      # Now, we can definitely checkout a conn
      Repo.checkout(fn ->
        fts_search(user, search_query, options)
      end)
    end
  end

  def maybe_locate_apid(apid, user, options) do
    known = Object.get_by_ap_id(apid)

    object_res =
      cond do
        known != nil -> {:ok, known}
        should_resolve_remote(options) -> Fetcher.fetch_object_from_id(apid)
        true -> nil
      end

    with {:ok, %Object{} = object} <- object_res,
         %Activity{} = activity <- Activity.get_create_by_object_ap_id(object.data["id"]),
         true <- activity.local || !should_restrict_local(user),
         true <- Visibility.visible_for_user?(activity, user) do
      activity
    else
      _ -> nil
    end
  end

  defp fts_search(user, search_query, options) do
    gin_limit = Pleroma.Config.get([__MODULE__, :gin_fuzzy_search_limit])

    try do
      if is_integer(gin_limit) do
        Repo.transact(fn ->
          # SET LOCAL statement cannot be parametrised it seems; safe since integer
          Repo.query!("SET LOCAL gin_fuzzy_search_limit TO #{gin_limit}", [])
          {:ok, do_fts_query(user, search_query, options)}
        end)
        |> then(fn
          {:ok, result} -> result
          error -> raise "#{__MODULE__}: db search transaction failed: #{inspect(error)}"
        end)
      else
        do_fts_query(user, search_query, options)
      end
    rescue
      _ -> []
    end
  end

  defp do_fts_query(user, search_query, options) do
    index_type = if Pleroma.Config.get([:database, :rum_enabled]), do: :rum, else: :gin
    limit = Enum.min([Keyword.get(options, :limit), 40])
    offset = Keyword.get(options, :offset, 0)
    author = Keyword.get(options, :author)

    Activity
    |> Activity.with_preloaded_object()
    |> Activity.restrict_deactivated_users()
    |> restrict_public()
    |> query_with(index_type, search_query)
    |> maybe_restrict_local(user)
    |> maybe_restrict_author(author)
    |> maybe_restrict_blocked(user)
    |> Pagination.fetch_paginated(
      %{"offset" => offset, "limit" => limit, "skip_order" => index_type == :rum},
      :offset
    )
  end

  def maybe_restrict_author(query, %User{} = author) do
    Activity.Queries.by_author(query, author)
  end

  def maybe_restrict_author(query, _), do: query

  def maybe_restrict_blocked(query, %User{} = user) do
    Activity.Queries.exclude_authors(query, User.blocked_users_ap_ids(user))
  end

  def maybe_restrict_blocked(query, _), do: query

  def restrict_public(q) do
    from([a, o] in q,
      where: fragment("?->>'type' = 'Create'", a.data),
      where: ^Pleroma.Constants.as_public() in a.recipients
    )
  end

  defp get_text_search_config() do
    %{rows: [[tsc]]} =
      Ecto.Adapters.SQL.query!(
        Pleroma.Repo,
        "select current_setting('default_text_search_config')::regconfig::oid;"
      )

    tsc
  end

  defp query_with(q, :gin, search_query) do
    tsc = get_text_search_config()

    from([a, o] in q,
      where:
        fragment(
          """
          to_tsvector(
            ?::oid::regconfig,
            COALESCE(?->>'summary', '') || ' ' || (?->>'content')
          ) @@ websearch_to_tsquery(?::oid::regconfig, ?)
          """,
          ^tsc,
          o.data,
          o.data,
          ^tsc,
          ^search_query
        )
    )
  end

  defp query_with(q, :rum, search_query) do
    tsc = get_text_search_config()

    from([a, o] in q,
      where:
        fragment(
          "? @@ websearch_to_tsquery(?::oid::regconfig, ?)",
          o.fts_content,
          ^tsc,
          ^search_query
        ),
      order_by: [fragment("? <=> now()::date", o.inserted_at)]
    )
  end

  def should_restrict_local(user) do
    limit = Pleroma.Config.get([:instance, :limit_to_local_content], :unauthenticated)

    case {limit, user} do
      {:all, _} -> true
      {:unauthenticated, %User{}} -> false
      {:unauthenticated, _} -> true
      {false, _} -> false
    end
  end

  def maybe_restrict_local(q, user) do
    case should_restrict_local(user) do
      true -> restrict_local(q)
      false -> q
    end
  end

  defp restrict_local(q), do: where(q, local: true)
end
