# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# Copyright © 2026 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Search do
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User

  require Logger

  import Ecto.Query

  @limit 20

  def search(query_string, opts \\ []) do
    query_string = String.trim(query_string)
    do_search(query_string, opts)
  end

  defp do_search("", _opts) do
    []
  end

  defp do_search(query_string, opts) do
    for_user = Keyword.get(opts, :for_user)
    local_only = should_restrict_local(for_user)
    resolve = Keyword.get(opts, :resolve, false) && !local_only

    action = fn -> search_action(query_string, for_user, local_only, resolve, opts) end

    if !resolve do
      Repo.checkout(action)
    else
      action.()
    end
  end

  defp search_action(query_string, for_user, local_only, resolve, opts) do
    is_uri = Regex.match?(~r/https?:/, query_string)
    explicit_nick = String.starts_with?(query_string, "@") && !String.contains?(query_string, " ")

    likely_nick =
      explicit_nick ||
        (String.contains?(query_string, "@") && !String.contains?(query_string, " "))

    []
    |> maybe_search(fn -> uri_match(query_string, is_uri, resolve) end)
    |> maybe_search(fn -> nick_match(query_string, likely_nick, resolve) end)
    |> maybe_search(fn ->
      fuzzy_matches(query_string, explicit_nick, for_user, local_only, opts)
    end)
    |> Enum.filter(&(&1 && (!local_only || &1.local)))
  end

  defp maybe_search([], finder) do
    case finder.() do
      [_ | _] = res -> res
      {:ok, a} when a != nil -> [a]
      {:error, _} -> []
      nil -> []
      [] -> []
      a -> [a]
    end
  end

  defp maybe_search(previous_results, _), do: previous_results

  defp do_uri_match(normalised_uri, resolve) do
    # This intentional omits block filters.
    # If an exactly matching URI is searched, there’s clearly intent to see the account anyway.
    # Similarly, if there’s a known, non-local exact match, we don't need to bother with a
    # fuzzy search even if results are later filtered to local-only. Thus always return non-local matches.
    known =
      from(u in User)
      |> where([u], u.ap_id == ^normalised_uri or u.uri == ^normalised_uri)
      |> filter_invisible_users()
      |> filter_internal_users()
      |> filter_deactivated_users()
      |> Repo.all()

    cond do
      known != [] -> known
      resolve -> User.fetch_by_ap_id(normalised_uri)
      true -> nil
    end
  end

  defp uri_match(uri, true, resolve) do
    with p = %URI{} <- URI.parse(uri),
         host when host != nil <- p.host do
      normalised_host = String.to_charlist(host) |> :idna.encode() |> to_string
      normalised_uri = %{p | host: normalised_host} |> URI.to_string()
      do_uri_match(normalised_uri, resolve)
    else
      _ -> nil
    end
  end

  defp uri_match(_, _, _), do: nil

  # NOTE: User.get_cached_by_nickname falls back to a netowrk lookup if not cached. DO NOT USE
  defp do_nick_match(nick, true), do: User.get_or_fetch_by_nickname(nick)
  defp do_nick_match(nick, false), do: User.get_by_nickname(nick)
  defp do_nick_match(_, _), do: nil

  defp verify_and_normalise_nick(nick) do
    nick =
      nick
      |> String.trim_leading("@")
      |> String.trim_trailing("@#{Pleroma.Web.WebFinger.Schema.domain()}")
      |> String.trim_trailing("@#{local_domain()}")

    case String.split(nick, "@", parts: 3) do
      "" ->
        nil

      # local nick
      [nick] ->
        nick

      # remote nick; maybe Unicode domain
      [name, domain] ->
        if Regex.match?(~r/[!-\,|@|?|<|>|[-`|{-~|\/|:|\s]/, domain) do
          nil
        else
          encoded_domain =
            domain
            |> String.to_charlist()
            |> :idna.encode()

          "#{name}@#{encoded_domain}"
        end

      # not a valid nick
      _ ->
        nil
    end
  end

  defp nick_match(nick, true, resolve) do
    normalised_nick = verify_and_normalise_nick(nick)

    if normalised_nick,
      do: do_nick_match(normalised_nick, resolve),
      else: nil
  end

  defp nick_match(_, _, _), do: nil

  defp fuzzy_matches(query_string, explicit_nick, for_user, local_only, opts) do
    following = Keyword.get(opts, :following, false)
    result_limit = Keyword.get(opts, :limit, @limit)
    offset = Keyword.get(opts, :offset, 0)

    nick_query = explicit_nick && verify_and_normalise_nick(query_string)

    if nick_query do
      nick_prefix_matches(nick_query, for_user, local_only, following, result_limit, offset)
    else
      fts_matches(query_string, for_user, local_only, following, result_limit, offset)
    end
  end

  defp nick_prefix_matches(nick_prefix, for_user, local_only, following, result_limit, offset) do
    base_query(for_user, following)
    |> where(
      [u],
      fragment(
        "starts_with(LOWER(?) COLLATE \"C\", LOWER(?::text) COLLATE \"C\")",
        u.nickname,
        ^nick_prefix
      )
    )
    |> filter_user_query(for_user, local_only)
    # prefer shorter (more similar) matches and especially prefer if currently matching the full name part
    |> select_merge(
      [u],
      %{
        search_rank:
          fragment(
            """
            length(?) / length(?)::float +
            CASE
              WHEN ? = ? THEN 1.0
              WHEN starts_with(LOWER(?) COLLATE "C", LOWER(?::text) COLLATE "C" || '@') THEN 0.5
              ELSE 0
            END
            """,
            ^nick_prefix,
            u.nickname,
            ^nick_prefix,
            u.nickname,
            u.nickname,
            ^nick_prefix
          )
          |> selected_as(:search_rank)
      }
    )
    |> order_by([u], desc: selected_as(:search_rank), desc: u.local, asc: u.id)
    |> Pagination.fetch_paginated(%{"offset" => offset, "limit" => result_limit}, :offset)
  end

  defp fts_matches(query_string, for_user, local_only, following, result_limit, offset) do
    gin_limit = Pleroma.Config.get([Pleroma.Search.DatabaseSearch, :gin_fuzzy_search_limit])

    if is_integer(gin_limit) do
      Repo.transact(fn ->
        # SET LOCAL statement cannot be parametrised it seems; safe because integer
        Repo.query!("SET LOCAL gin_fuzzy_search_limit TO #{gin_limit}", [])

        {:ok, do_fts_search(query_string, for_user, local_only, following, offset, result_limit)}
      end)
      |> then(fn
        {:ok, result} ->
          result

        error ->
          Logger.error("#{__MODULE__}: user search transaction failed: #{inspect(error)}")
          []
      end)
    else
      do_fts_search(query_string, for_user, local_only, following, offset, result_limit)
    end
  end

  defp do_fts_search(query_string, for_user, local_only, following, offset, result_limit) do
    base_query(for_user, following)
    |> filter_user_query(for_user, local_only)
    |> fts_search(query_string)
    |> trigram_rank(query_string)
    |> order_by([u], desc: selected_as(:search_rank), desc: u.local, asc: u.id)
    |> Pagination.fetch_paginated(%{"offset" => offset, "limit" => result_limit}, :offset)
  end

  defp base_query(%User{} = user, true), do: User.get_friends_query(user)
  defp base_query(_user, _following), do: User

  defp filter_user_query(query, for_user, local_only) do
    query
    |> filter_invisible_users()
    |> filter_internal_users()
    |> filter_deactivated_users()
    |> filter_blocked_user(for_user)
    |> filter_blocked_domains(for_user)
    |> maybe_restrict_local(local_only)
  end

  defp fts_search(query, query_string) do
    from(
      u in query,
      where:
        fragment(
          # The ts_vector and LOWER expression must exactly match the indexes
          # (only the collation _inisde_ the LOWER call is relevant, the outer part just ensures we have
          #  a deterministic collation supported by starts_with and allowing fast byte comparisons)
          """
          starts_with(LOWER(?) COLLATE "C", LOWER(?::text) COLLATE "C") OR
          to_tsvector('simple', ?) @@ plainto_tsquery('simple', ?::text)
          """,
          u.nickname,
          ^query_string,
          u.name,
          ^query_string
        )
    )
  end

  # Considers nickname match, localized nickname match, name match; preferences nickname match
  defp trigram_rank(query, query_string) do
    from(
      u in query,
      select_merge: %{
        search_rank:
          fragment(
            """
            similarity(?, ?) +
            similarity(?, regexp_replace(?, '@.+', '')) +
            similarity(?, trim(coalesce(?, '')))
            """,
            ^query_string,
            u.nickname,
            ^query_string,
            u.nickname,
            ^query_string,
            u.name
          )
          |> selected_as(:search_rank)
      }
    )
  end

  defp filter_invisible_users(query) do
    from(q in query, where: q.invisible == false)
  end

  defp filter_internal_users(query) do
    from(q in query, where: q.actor_type != "Application")
  end

  defp filter_deactivated_users(query) do
    from(q in query, where: q.is_active == true)
  end

  defp filter_blocked_user(query, %User{} = blocker) do
    query
    |> join(:left, [u], b in Pleroma.UserRelationship,
      as: :blocks,
      on: b.relationship_type == ^:block and b.source_id == ^blocker.id and u.id == b.target_id
    )
    |> where([blocks: b], is_nil(b.target_id))
  end

  defp filter_blocked_user(query, _), do: query

  defp filter_blocked_domains(query, %User{domain_blocks: domain_blocks})
       when length(domain_blocks) > 0 do
    domains = Enum.join(domain_blocks, ",")

    from(
      q in query,
      where: fragment("split_part(ap_id, '/', 3) NOT IN (?)", ^domains)
    )
  end

  defp filter_blocked_domains(query, _), do: query

  defp limit, do: Pleroma.Config.get([:instance, :limit_to_local_content], :unauthenticated)

  defp should_restrict_local(user) do
    case {limit(), user} do
      {:all, _} -> true
      {:unauthenticated, %User{}} -> false
      {:unauthenticated, _} -> true
      {false, _} -> false
    end
  end

  defp maybe_restrict_local(q, true), do: restrict_local(q)
  defp maybe_restrict_local(q, false), do: q

  defp restrict_local(q), do: where(q, [u], u.local == true)

  defp local_domain, do: Pleroma.Config.get([Pleroma.Web.Endpoint, :url, :host])
end
