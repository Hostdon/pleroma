defmodule Pleroma.Workers.SearchIndexingWorker do
  use Pleroma.Workers.WorkerHelper, queue: "search_indexing"

  @impl Oban.Worker

  def perform(%Job{args: %{"op" => "add_to_index", "activity" => activity_id}}) do
    activity = Pleroma.Activity.get_by_id_with_object(activity_id)

    search_module = Pleroma.Config.get([Pleroma.Search, :module])

    search_module.add_to_index(activity)

    :ok
  end

  def perform(%Job{args: %{"op" => "remove_from_index", "object" => object_id}}) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module])

    # Fake the object so we can remove it from the index without having to keep it in the DB
    search_module.remove_from_index(%Pleroma.Object{id: object_id})

    :ok
  end
end
