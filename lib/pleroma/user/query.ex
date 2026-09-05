# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Query do
  @moduledoc """
  User query builder module. Builds query from new query or another user query.

    ## Example:
        query = Pleroma.User.Query.build(%{nickname: "nickname"})
        another_query = Pleroma.User.Query.build(query, %{email: "email@example.com"})
        Pleroma.Repo.all(query)
        Pleroma.Repo.all(another_query)

  Adding new rules:
    - *ilike criteria*
      - add field to @ilike_criteria list
      - pass non empty string
      - e.g. Pleroma.User.Query.build(%{nickname: "nickname"})
    - *equal criteria*
      - add field to @equal_criteria list
      - pass non empty string
      - e.g. Pleroma.User.Query.build(%{email: "email@example.com"})
    - *contains criteria*
      - add field to @containns_criteria list
      - pass values list
      - e.g. Pleroma.User.Query.build(%{ap_id: ["http://ap_id1", "http://ap_id2"]})
  """
  import Ecto.Query
  import Pleroma.Web.Utils.Guards, only: [not_empty_string: 1]

  alias Pleroma.FollowingRelationship
  alias Pleroma.User

  @type criteria ::
          %{
            tags: [String.t()],
            name: String.t(),
            email: String.t() | [String.t()],
            local: boolean(),
            external: boolean(),
            active: boolean(),
            deactivated: boolean(),
            need_approval: boolean(),
            unconfirmed: boolean(),
            is_admin: boolean(),
            is_moderator: boolean(),
            is_suggested: boolean(),
            is_discoverable: boolean(),
            super_users: boolean(),
            invisible: boolean(),
            internal: boolean(),
            followers: User.t(),
            friends: User.t(),
            recipients_from_activity: [String.t()],
            nickname: [String.t()] | String.t(),
            nickname_substr: String.t(),
            nickname_suffix: String.t(),
            ap_id: [String.t()],
            order_by: term(),
            select: term(),
            limit: pos_integer(),
            actor_types: [String.t()]
          }
          | map()

  @ilike_criteria [:nickname_substr, :name]
  @equal_criteria [:email]
  @contains_criteria [:ap_id, :email]

  @spec build(Query.t(), criteria()) :: Query.t()
  def build(query \\ base_query(), criteria) do
    prepare_query(query, criteria)
  end

  @spec paginate(Ecto.Query.t(), pos_integer(), pos_integer()) :: Ecto.Query.t()
  def paginate(query, page, page_size) do
    from(u in query,
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
  end

  defp base_query do
    from(u in User)
  end

  defp prepare_query(query, criteria) do
    criteria
    |> Map.put_new(:internal, false)
    |> Enum.reduce(query, &compose_query/2)
  end

  defp compose_query({key, value}, query)
       when key in @ilike_criteria and not_empty_string(value) do
    key = if key == :nickname_substr, do: :nickname, else: key
    where(query, [u], ilike(field(u, ^key), ^"%#{escape_sql_like(value)}%"))
  end

  defp compose_query({:nickname_suffix, value}, query) when not_empty_string(value) do
    where(query, [u], ilike(u.nickname, ^"%#{escape_sql_like(value)}"))
  end

  defp compose_query({:nickname, nick}, query) when not_empty_string(nick) do
    where(query, [u], fragment("LOWER(?) = LOWER(?)", u.nickname, ^nick))
  end

  defp compose_query({:invisible, bool}, query) when is_boolean(bool) do
    where(query, [u], u.invisible == ^bool)
  end

  defp compose_query({key, value}, query)
       when key in @equal_criteria and not_empty_string(value) do
    where(query, [u], ^[{key, value}])
  end

  defp compose_query({key, values}, query) when key in @contains_criteria and is_list(values) do
    where(query, [u], field(u, ^key) in ^values)
  end

  defp compose_query({:nickname, nicks}, query) when is_list(nicks) do
    where(
      query,
      [u],
      fragment("LOWER(?)", u.nickname) in fragment(
        "(SELECT LOWER(UNNEST(?::text[])))",
        ^nicks
      )
    )
  end

  defp compose_query({:tags, tags}, query) when is_list(tags) and length(tags) > 0 do
    where(query, [u], fragment("? && ?", u.tags, ^tags))
  end

  defp compose_query({:is_admin, bool}, query) do
    where(query, [u], u.is_admin == ^bool)
  end

  defp compose_query({:actor_types, actor_types}, query) when is_list(actor_types) do
    where(query, [u], u.actor_type in ^actor_types)
  end

  defp compose_query({:is_moderator, bool}, query) do
    where(query, [u], u.is_moderator == ^bool)
  end

  defp compose_query({:super_users, _}, query) do
    where(
      query,
      [u],
      u.is_admin or u.is_moderator
    )
  end

  defp compose_query({:local, _}, query), do: location_query(query, true)

  defp compose_query({:external, _}, query), do: location_query(query, false)

  defp compose_query({:active, _}, query) do
    where(query, [u], u.is_active == true)
    |> where([u], u.is_approved == true)
    |> where([u], u.is_confirmed == true)
  end

  defp compose_query({:deactivated, false}, query) do
    where(query, [u], u.is_active == true)
  end

  defp compose_query({:deactivated, true}, query) do
    where(query, [u], u.is_active == false)
  end

  defp compose_query({:confirmation_pending, bool}, query) do
    where(query, [u], u.is_confirmed != ^bool)
  end

  defp compose_query({:need_approval, _}, query) do
    where(query, [u], u.is_approved == false)
  end

  defp compose_query({:unconfirmed, _}, query) do
    where(query, [u], u.is_confirmed == false)
  end

  defp compose_query({:is_suggested, bool}, query) do
    where(query, [u], u.is_suggested == ^bool)
  end

  defp compose_query({:is_discoverable, bool}, query) do
    where(query, [u], u.is_discoverable == ^bool)
  end

  defp compose_query({:followers, %User{id: id}}, query) do
    query
    |> where([u], u.id != ^id)
    |> join(:inner, [u], r in FollowingRelationship,
      as: :relationships,
      on: r.following_id == ^id and r.follower_id == u.id
    )
    |> where([relationships: r], r.state == ^:follow_accept)
  end

  defp compose_query({:friends, %User{id: id}}, query) do
    query
    |> where([u], u.id != ^id)
    |> join(:inner, [u], r in FollowingRelationship,
      as: :relationships,
      on: r.following_id == u.id and r.follower_id == ^id
    )
    |> where([relationships: r], r.state == ^:follow_accept)
  end

  defp compose_query({:recipients_from_activity, to}, query) do
    following_query =
      from(u in User,
        join: f in FollowingRelationship,
        on: u.id == f.following_id,
        where: f.state == ^:follow_accept,
        where: u.follower_address in ^to,
        select: f.follower_id
      )

    from(u in query,
      where: u.ap_id in ^to or u.id in subquery(following_query)
    )
  end

  defp compose_query({:order_by, key}, query) do
    order_by(query, [u], field(u, ^key))
  end

  defp compose_query({:select, keys}, query) do
    select(query, [u], ^keys)
  end

  defp compose_query({:limit, limit}, query) do
    limit(query, ^limit)
  end

  defp compose_query({:internal, false}, query) do
    query
    |> where([u], not is_nil(u.nickname))
    |> where([u], fragment("LOWER(?) NOT LIKE 'internal.%'", u.nickname))
  end

  defp compose_query(_unsupported_param, query), do: query

  defp location_query(query, local) do
    where(query, [u], u.local == ^local)
  end

  defp escape_sql_like(literal) do
    # https://www.postgresql.org/docs/current/functions-matching.html#FUNCTIONS-LIKE
    # (assumes the default config of standard_conforming_strings=on)
    literal
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
