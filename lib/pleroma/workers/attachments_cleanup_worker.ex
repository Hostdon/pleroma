# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.AttachmentsCleanupWorker do
  import Ecto.Query

  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.Repo

  use Pleroma.Workers.WorkerHelper, queue: "attachments_cleanup"

  @doc """
  Takes object data and if necessary enqueues a job,
  deleting all attachments of the post eligible for cleanup
  """
  @spec enqueue_if_needed(map()) :: {:ok, Oban.Job.t()} | {:ok, :skip} | {:error, any()}
  def enqueue_if_needed(%{
        "actor" => actor,
        "attachment" => [_ | _] = attachments
      }) do
    with true <- Config.get([:instance, :cleanup_attachments]),
         true <- URI.parse(actor).host == Pleroma.Web.Endpoint.host(),
         [_ | _] <- attachments do
      enqueue(
        "cleanup_attachments",
        %{"actor" => actor, "attachments" => attachments},
        schedule_in: Config.get!([:instance, :cleanup_attachments_delay])
      )
    else
      _ -> {:ok, :skip}
    end
  end

  def enqueue_if_needed(_), do: {:ok, :skip}

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "op" => "cleanup_attachments",
          "attachments" => [_ | _] = attachments,
          "actor" => actor
        }
      }) do
    attachments
    |> filter_active_media_objects()
    |> Enum.flat_map(fn item -> Enum.map(item["url"], & &1["href"]) end)
    |> fetch_all_objects_for_files()
    |> prepare_objects(actor, Enum.map(attachments, & &1["name"]))
    |> filter_reused_files()
    |> do_clean()

    {:ok, :success}
  end

  # Left over already enqueued jobs in the old format
  # This function clause can be deleted once sufficient time passed after 3.14
  def perform(%Job{
        args: %{
          "op" => "cleanup_attachments",
          "object" => %{"data" => data}
        }
      }) do
    enqueue_if_needed(data)
  end

  def perform(%Job{args: %{"op" => "cleanup_attachments", "object" => _object}}), do: {:ok, :skip}

  defp do_clean({object_ids, attachment_urls}) do
    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

    base_url =
      String.trim_trailing(
        Pleroma.Upload.base_url(),
        "/"
      )

    Enum.each(attachment_urls, fn href ->
      href
      |> String.trim_leading("#{base_url}")
      |> uploader.delete_file()
    end)

    delete_objects(object_ids)
  end

  defp delete_objects([_ | _] = object_ids) do
    Repo.delete_all(from(o in Object, where: o.id in ^object_ids))
  end

  defp delete_objects(_), do: :ok

  # we should delete 1 unused attachment object for any given attachment,
  # but don't delete the files if also referenced by another attachment object
  defp filter_reused_files(objects) do
    Enum.reduce(objects, {[], []}, fn {href, %{id: id, count: count}}, {ids, hrefs} ->
      with 1 <- count do
        {ids ++ [id], hrefs ++ [href]}
      else
        _ -> {ids ++ [id], hrefs}
      end
    end)
  end

  defp prepare_objects(objects, actor, names) do
    objects
    |> Enum.reduce(%{}, fn %{
                             id: id,
                             data: %{
                               "url" => [%{"href" => href}],
                               "actor" => obj_actor,
                               "name" => name
                             }
                           },
                           acc ->
      Map.update(acc, href, %{id: id, count: 1}, fn val ->
        case obj_actor == actor and name in names do
          true ->
            # set id of the actor's object that will be deleted
            %{val | id: id, count: val.count + 1}

          false ->
            # another actor's object, just increase count to not delete file
            %{val | count: val.count + 1}
        end
      end)
    end)
  end

  defp fetch_all_objects_for_files(hrefs) do
    from(o in Object,
      where:
        fragment(
          "to_jsonb(array(select jsonb_array_elements((?)#>'{url}') ->> 'href' where jsonb_typeof((?)#>'{url}') = 'array'))::jsonb \\?| (?)",
          o.data,
          o.data,
          ^hrefs
        )
    )
    # The query above can be time consumptive on large instances until we
    # refactor how uploads are stored
    |> Repo.all(timeout: :infinity)
  end

  # do not delete attachment objects still referenced in a non-deleted status
  def filter_active_media_objects(objects) do
    obj_id_candidates =
      objects
      |> Enum.map(fn data -> data["id"] end)
      |> Enum.reject(&(&1 == nil))

    # Needs to be subquery to prevent json_array_elelemtns to run on null values
    objects_with_attachments =
      Object
      |> where([o], fragment("jsonb_typeof(?->'attachment') = 'array'", o.data))

    used_ids =
      subquery(objects_with_attachments)
      |> join(
        :cross_lateral,
        [o],
        ua in fragment("jsonb_array_elements(?->'attachment')", o.data)
      )
      |> join(:inner, [_o, ua], id in fragment("UNNEST(?::text[])", ^obj_id_candidates),
        on: fragment("? = ?->>'id'", id, ua)
      )
      |> select([_o, _ua, id], fragment("?", id))
      |> distinct(true)
      |> Repo.all(timeout: :infinity)

    Enum.filter(objects, fn data -> data["id"] && data["id"] not in used_ids end)
  end
end
