# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Pagination do
  @moduledoc """
  Implements Mastodon-compatible pagination.
  """

  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Repo

  @type type :: :keyset | :offset

  @default_limit 20
  @max_limit 40
  @page_keys ["max_id", "min_id", "limit", "since_id", "order"]

  def page_keys, do: @page_keys

  @spec fetch_paginated(Ecto.Query.t(), map(), type(), atom() | nil) :: [Ecto.Schema.t()]
  def fetch_paginated(query, params, type \\ :keyset, table_binding \\ nil)

  def fetch_paginated(query, %{total: true} = params, :keyset, table_binding) do
    total = Repo.aggregate(query, :count, :id)

    %{
      total: total,
      items: fetch_paginated(query, Map.drop(params, [:total]), :keyset, table_binding)
    }
  end

  def fetch_paginated(query, params, :keyset, table_binding) do
    options = cast_params(params)

    query
    |> paginate(options, :keyset, table_binding)
    |> Repo.all()
    |> enforce_order(options)
  end

  def fetch_paginated(query, %{total: true} = params, :offset, table_binding) do
    total =
      query
      |> Ecto.Query.exclude(:left_join)
      |> Repo.aggregate(:count, :id)

    %{
      total: total,
      items: fetch_paginated(query, Map.drop(params, [:total]), :offset, table_binding)
    }
  end

  def fetch_paginated(query, params, :offset, table_binding) do
    options = cast_params(params)

    query
    |> paginate(options, :offset, table_binding)
    |> Repo.all()
  end

  @spec paginate(Ecto.Query.t(), map(), type(), atom() | nil) :: [Ecto.Schema.t()]
  def paginate(query, options, method \\ :keyset, table_binding \\ nil)

  def paginate(list, options, _method, _table_binding) when is_list(list) do
    offset = options[:offset] || 0
    limit = options[:limit] || 0
    Enum.slice(list, offset, limit)
  end

  def paginate(query, options, :keyset, table_binding) do
    query
    |> restrict(:min_id, options, table_binding)
    |> restrict(:since_id, options, table_binding)
    |> restrict(:max_id, options, table_binding)
    |> restrict(:order, options, table_binding)
    |> restrict(:limit, options, table_binding)
  end

  def paginate(query, options, :offset, table_binding) do
    query
    |> restrict(:order, options, table_binding)
    |> restrict(:offset, options, table_binding)
    |> restrict(:limit, options, table_binding)
  end

  defp cast_params(params) do
    param_types = %{
      min_id: :string,
      since_id: :string,
      max_id: :string,
      offset: :integer,
      limit: :integer,
      skip_extra_order: :boolean,
      skip_order: :boolean
    }

    changeset = cast({%{}, param_types}, params, Map.keys(param_types))
    changeset.changes
  end

  defp restrict(query, :min_id, %{min_id: min_id}, table_binding) do
    where(query, [{q, table_position(query, table_binding)}], q.id > ^min_id)
  end

  defp restrict(query, :since_id, %{since_id: since_id}, table_binding) do
    where(query, [{q, table_position(query, table_binding)}], q.id > ^since_id)
  end

  defp restrict(query, :max_id, %{max_id: max_id}, table_binding) do
    where(query, [{q, table_position(query, table_binding)}], q.id < ^max_id)
  end

  defp restrict(query, :order, %{skip_order: true}, _), do: query

  defp restrict(%{order_bys: [_ | _]} = query, :order, %{skip_extra_order: true}, _), do: query

  defp restrict(query, :order, %{min_id: _}, table_binding) do
    order_by(
      query,
      [{u, table_position(query, table_binding)}],
      fragment("? asc nulls last", u.id)
    )
  end

  defp restrict(query, :order, _options, table_binding) do
    order_by(
      query,
      [{u, table_position(query, table_binding)}],
      fragment("? desc nulls last", u.id)
    )
  end

  defp restrict(query, :offset, %{offset: offset}, _table_binding) do
    offset(query, ^offset)
  end

  defp restrict(query, :limit, options, _table_binding) do
    limit =
      case Map.get(options, :limit, @default_limit) do
        limit when limit < @max_limit -> limit
        _ -> @max_limit
      end

    query
    |> limit(^limit)
  end

  defp restrict(query, _, _, _), do: query

  defp enforce_order(result, %{min_id: _}) do
    result
    |> Enum.reverse()
  end

  defp enforce_order(result, _), do: result

  defp table_position(%Ecto.Query{} = query, binding_name) do
    Map.get(query.aliases, binding_name, 0)
  end

  defp table_position(_, _), do: 0
end
