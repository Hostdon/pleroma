# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.Elasticsearch.Store do
  @behaviour Elasticsearch.Store
  alias Pleroma.Search.Elasticsearch.Cluster
  require Logger

  alias Pleroma.Repo

  @impl true
  def stream(schema) do
    Repo.stream(schema)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def search(_, _, _, :skip), do: []

  def search(:raw, index, q) do
    with {:ok, raw_results} <- Elasticsearch.post(Cluster, "/#{index}/_search", q) do
      results =
        raw_results
        |> Map.get("hits", %{})
        |> Map.get("hits", [])

      {:ok, results}
    else
      {:error, e} ->
        Logger.error(e)
        {:error, e}
    end
  end

  def search(:activities, q) do
    with {:ok, results} <- search(:raw, "activities", q) do
      results
      |> Enum.map(fn result -> result["_id"] end)
      |> Pleroma.Activity.all_by_ids_with_object()
    else
      e ->
        Logger.error(e)
        []
    end
  end
end
