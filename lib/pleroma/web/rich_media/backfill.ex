# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Backfill do
  use Pleroma.Workers.WorkerHelper,
    queue: "rich_media_backfill",
    unique: [period: 300, states: Oban.Job.states(), keys: [:op, :url_hash]]

  alias Pleroma.Web.RichMedia.Card
  alias Pleroma.Web.RichMedia.Parser
  alias Pleroma.Web.RichMedia.Parser.TTL
  alias Pleroma.Workers.RichMediaExpirationWorker

  require Logger

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  def start(%{url: url} = args) when is_binary(url) do
    url_hash = Card.url_to_hash(url)

    args =
      args
      |> Map.put(:url_hash, url_hash)

    __MODULE__.enqueue("rich_media_backfill", args)
  end

  def perform(%Oban.Job{args: %{"op" => "rich_media_backfill", "url" => url} = args})
      when is_binary(url) do
    run(args)
  end

  def run(%{"url" => url, "url_hash" => url_hash} = args) do
    case Parser.parse(url) do
      {:ok, fields} ->
        {:ok, card} = Card.create(url, fields)

        maybe_schedule_expiration(url, fields)

        if Map.has_key?(args, "activity_id") do
          stream_update(args)
        end

        warm_cache(url_hash, card)
        :ok

      {:error, {:invalid_metadata, fields}} ->
        Logger.debug("Rich media incomplete or invalid metadata for #{url}: #{inspect(fields)}")
        negative_cache(url_hash, :timer.minutes(30))

      {:error, :body_too_large} ->
        Logger.error("Rich media error for #{url}: :body_too_large")
        negative_cache(url_hash, :timer.minutes(30))

      {:error, {:content_type, type}} ->
        Logger.debug("Rich media error for #{url}: :content_type is #{type}")
        negative_cache(url_hash, :timer.minutes(30))

      {:error, {:url, reason}} ->
        Logger.debug("Rich media error for #{url}: refusing URL #{inspect(reason)}")
        negative_cache(url_hash, :timer.minutes(180))

      e ->
        Logger.debug("Rich media error for #{url}: #{inspect(e)}")
        {:error, e}
    end
  end

  def run(e) do
    Logger.error("Rich media failure - invalid args: #{inspect(e)}")
    {:discard, :invalid}
  end

  defp maybe_schedule_expiration(url, fields) do
    case TTL.process(fields, url) do
      {:ok, ttl} when is_number(ttl) ->
        timestamp = DateTime.from_unix!(ttl)

        RichMediaExpirationWorker.new(%{"url" => url}, scheduled_at: timestamp)
        |> Oban.insert()

      _ ->
        :ok
    end
  end

  defp stream_update(%{"activity_id" => activity_id}) do
    Logger.debug("Rich media backfill: streaming update for activity #{activity_id}")

    Pleroma.Activity.get_by_id(activity_id)
    |> Pleroma.Activity.normalize()
    |> Pleroma.Web.ActivityPub.ActivityPub.stream_out()
  end

  defp warm_cache(key, val), do: @cachex.put(:rich_media_cache, key, val)

  def negative_cache(key, ttl \\ :timer.minutes(30)) do
    @cachex.put(:rich_media_cache, key, nil, ttl: ttl)
    {:discard, :error}
  end
end
