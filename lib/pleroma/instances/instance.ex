# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances.Instance do
  @moduledoc "Instance."

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  alias Pleroma.Instances
  alias Pleroma.Instances.Instance
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Workers.BackgroundWorker

  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  require Logger

  schema "instances" do
    field(:host, :string)
    field(:unreachable_since, :naive_datetime_usec)
    field(:favicon, :string)
    field(:metadata_updated_at, :naive_datetime)
    field(:nodeinfo, :map, default: %{})

    timestamps()
  end

  defdelegate host(url_or_host), to: Instances

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:host, :unreachable_since, :favicon, :nodeinfo, :metadata_updated_at])
    |> validate_required([:host])
    |> unique_constraint(:host)
  end

  def filter_reachable([]), do: %{}

  def filter_reachable(urls_or_hosts) when is_list(urls_or_hosts) do
    hosts =
      urls_or_hosts
      |> Enum.map(&(&1 && host(&1)))
      |> Enum.filter(&(to_string(&1) != ""))

    unreachable_since_by_host =
      Repo.all(
        from(i in Instance,
          where: i.host in ^hosts,
          select: {i.host, i.unreachable_since}
        )
      )
      |> Map.new(& &1)

    reachability_datetime_threshold = Instances.reachability_datetime_threshold()

    for entry <- Enum.filter(urls_or_hosts, &is_binary/1) do
      host = host(entry)
      unreachable_since = unreachable_since_by_host[host]

      if !unreachable_since ||
           NaiveDateTime.compare(unreachable_since, reachability_datetime_threshold) == :gt do
        {entry, unreachable_since}
      end
    end
    |> Enum.filter(& &1)
    |> Map.new(& &1)
  end

  def reachable?(url_or_host) when is_binary(url_or_host) do
    !Repo.one(
      from(i in Instance,
        where:
          i.host == ^host(url_or_host) and
            i.unreachable_since <= ^Instances.reachability_datetime_threshold(),
        select: true
      )
    )
  end

  def reachable?(url_or_host) when is_binary(url_or_host), do: true

  def set_reachable(url_or_host) when is_binary(url_or_host) do
    with host <- host(url_or_host),
         %Instance{} = existing_record <- Repo.get_by(Instance, %{host: host}) do
      {:ok, _instance} =
        existing_record
        |> changeset(%{unreachable_since: nil})
        |> Repo.update()
    end
  end

  def set_reachable(_), do: {:error, nil}

  def set_unreachable(url_or_host, unreachable_since \\ nil)

  def set_unreachable(url_or_host, unreachable_since) when is_binary(url_or_host) do
    unreachable_since = parse_datetime(unreachable_since) || NaiveDateTime.utc_now()
    host = host(url_or_host)
    existing_record = Repo.get_by(Instance, %{host: host})

    changes = %{unreachable_since: unreachable_since}

    cond do
      is_nil(existing_record) ->
        %Instance{}
        |> changeset(Map.put(changes, :host, host))
        |> Repo.insert()

      existing_record.unreachable_since &&
          NaiveDateTime.compare(existing_record.unreachable_since, unreachable_since) != :gt ->
        {:ok, existing_record}

      true ->
        existing_record
        |> changeset(changes)
        |> Repo.update()
    end
  end

  def set_unreachable(_, _), do: {:error, nil}

  def get_consistently_unreachable do
    reachability_datetime_threshold = Instances.reachability_datetime_threshold()

    from(i in Instance,
      where: ^reachability_datetime_threshold > i.unreachable_since,
      order_by: i.unreachable_since,
      select: {i.host, i.unreachable_since}
    )
    |> Repo.all()
  end

  defp parse_datetime(datetime) when is_binary(datetime) do
    NaiveDateTime.from_iso8601(datetime)
  end

  defp parse_datetime(datetime), do: datetime

  def needs_update(nil), do: true

  def needs_update(%Instance{metadata_updated_at: nil}), do: true

  def needs_update(%Instance{metadata_updated_at: metadata_updated_at}) do
    now = NaiveDateTime.utc_now()
    NaiveDateTime.diff(now, metadata_updated_at) > 86_400
  end

  def local do
    %Instance{
      host: Pleroma.Web.Endpoint.host(),
      favicon: Pleroma.Web.Endpoint.url() <> "/favicon.png",
      nodeinfo: Pleroma.Web.Nodeinfo.NodeinfoController.raw_nodeinfo()
    }
  end

  def update_metadata(%URI{host: host} = uri) do
    Logger.debug("Checking metadata for #{host}")
    existing_record = Repo.get_by(Instance, %{host: host})

    if reachable?(host) do
      do_update_metadata(uri, existing_record)
    else
      {:discard, :unreachable}
    end
  end

  defp do_update_metadata(%URI{host: host} = uri, existing_record) do
    if existing_record do
      if needs_update(existing_record) do
        Logger.info("Updating metadata for #{host}")
        favicon = scrape_favicon(uri)
        nodeinfo = scrape_nodeinfo(uri)

        existing_record
        |> changeset(%{
          host: host,
          favicon: favicon,
          nodeinfo: nodeinfo,
          metadata_updated_at: NaiveDateTime.utc_now()
        })
        |> Repo.update()
      else
        {:discard, "Does not require update"}
      end
    else
      favicon = scrape_favicon(uri)
      nodeinfo = scrape_nodeinfo(uri)

      Logger.info("Creating metadata for #{host}")

      %Instance{}
      |> changeset(%{
        host: host,
        favicon: favicon,
        nodeinfo: nodeinfo,
        metadata_updated_at: NaiveDateTime.utc_now()
      })
      |> Repo.insert()
    end
  end

  def get_favicon(%URI{host: host}) do
    existing_record = Repo.get_by(Instance, %{host: host})

    if existing_record do
      existing_record.favicon
    else
      nil
    end
  end

  defp scrape_nodeinfo(%URI{} = instance_uri) do
    with true <- Pleroma.Config.get([:instances_nodeinfo, :enabled]),
         {_, true} <- {:reachable, reachable?(instance_uri.host)},
         {:ok, %Tesla.Env{status: 200, body: body}} <-
           Tesla.get(
             "https://#{instance_uri.host}/.well-known/nodeinfo",
             headers: [{"Accept", "application/json"}]
           ),
         {:ok, json} <- Jason.decode(body),
         {:ok, %{"links" => links}} <- {:ok, json},
         {:ok, %{"href" => href}} <-
           {:ok,
            Enum.find(links, &(&1["rel"] == "http://nodeinfo.diaspora.software/ns/schema/2.0"))},
         {:ok, %Tesla.Env{body: data}} <-
           Pleroma.HTTP.get(href, [{"accept", "application/json"}], []),
         {:length, true} <- {:length, String.length(data) < 50_000},
         {:ok, nodeinfo} <- Jason.decode(data) do
      nodeinfo
    else
      {:reachable, false} ->
        Logger.debug(
          "Instance.scrape_nodeinfo(\"#{to_string(instance_uri)}\") ignored unreachable host"
        )

        nil

      {:length, false} ->
        Logger.debug(
          "Instance.scrape_nodeinfo(\"#{to_string(instance_uri)}\") ignored too long body"
        )

        nil

      _ ->
        nil
    end
  end

  defp scrape_favicon(%URI{} = instance_uri) do
    with true <- Pleroma.Config.get([:instances_favicons, :enabled]),
         {_, true} <- {:reachable, reachable?(instance_uri.host)},
         {:ok, %Tesla.Env{body: html}} <-
           Pleroma.HTTP.get(to_string(instance_uri), [{"accept", "text/html"}], []),
         {_, [favicon_rel | _]} when is_binary(favicon_rel) <-
           {:parse, html |> Floki.parse_document!() |> Floki.attribute("link[rel=icon]", "href")},
         {_, favicon} when is_binary(favicon) <-
           {:merge, URI.merge(instance_uri, favicon_rel) |> to_string()},
         {:length, true} <- {:length, String.length(favicon) < 255} do
      favicon
    else
      {:reachable, false} ->
        Logger.debug(
          "Instance.scrape_favicon(\"#{to_string(instance_uri)}\") ignored unreachable host"
        )

        nil

      _ ->
        nil
    end
  end

  @doc """
  Deletes all users from an instance in a background task, thus also deleting
  all of those users' activities and notifications.
  """
  def delete_users_and_activities(host) when is_binary(host) do
    BackgroundWorker.enqueue("delete_instance", %{"host" => host})
  end

  def perform(:delete_instance, host) when is_binary(host) do
    User.Query.build(%{nickname: "@#{host}"})
    |> Repo.chunk_stream(100, :batches)
    |> Stream.each(fn users ->
      users
      |> Enum.each(fn user ->
        User.perform(:delete, user)
      end)
    end)
    |> Stream.run()
  end

  def get_by_url(url_or_host) do
    url = host(url_or_host)
    Repo.get_by(Instance, host: url)
  end

  def get_cached_by_url(url_or_host) do
    url = host(url_or_host)

    if url == Pleroma.Web.Endpoint.host() do
      {:ok, local()}
    else
      @cachex.fetch!(:instances_cache, "instances:#{url}", fn _ ->
        with %Instance{} = instance <- get_by_url(url) do
          {:commit, {:ok, instance}}
        else
          _ -> {:ignore, nil}
        end
      end)
    end
  end
end
