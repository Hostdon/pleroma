defmodule Pleroma.Workers.SearchIndexingWorker do
  use Pleroma.Workers.WorkerHelper, queue: "search_indexing"

  defp search_module(), do: Pleroma.Config.get!([Pleroma.Search, :module])

  def enqueue("add_to_index", params, worker_args) do
    if Kernel.function_exported?(search_module(), :add_to_index, 1) do
      do_enqueue("add_to_index", params, worker_args)
    else
      # XXX: or {:ok, nil} to more closely match Oban.inset()'s {:ok, job}?
      #      or similar to unique coflict: %Oban.Job{conflict?: true} (but omitting all other fileds...)
      :ok
    end
  end

  def enqueue("remove_from_index", params, worker_args) do
    if Kernel.function_exported?(search_module(), :remove_from_index, 1) do
      do_enqueue("remove_from_index", params, worker_args)
    else
      :ok
    end
  end

  @impl Oban.Worker
  def perform(%Job{args: %{"op" => "add_to_index", "activity" => activity_id}}) do
    activity = Pleroma.Activity.get_by_id_with_object(activity_id)

    search_module().add_to_index(activity)

    :ok
  end

  def perform(%Job{args: %{"op" => "remove_from_index", "object" => object_id}}) do
    # Fake the object so we can remove it from the index without having to keep it in the DB
    search_module().remove_from_index(%Pleroma.Object{id: object_id})

    :ok
  end
end
