defmodule Pleroma.Object.Pruner do
  @moduledoc """
  Prunes objects from the database.
  """
  @cutoff 30

  alias Pleroma.Object
  alias Pleroma.Delivery
  alias Pleroma.Repo
  import Ecto.Query

  def prune_tombstoned_deliveries do
    from(d in Delivery)
    |> join(:inner, [d], o in Object, on: d.object_id == o.id)
    |> where([d, o], fragment("?->>'type' = ?", o.data, "Tombstone"))
    |> Repo.delete_all(timeout: :infinity)
  end

  def prune_tombstones do
    before_time = cutoff()

    from(o in Object,
      where: fragment("?->>'type' = ?", o.data, "Tombstone") and o.inserted_at < ^before_time
    )
    |> Repo.delete_all(timeout: :infinity, on_delete: :delete_all)
  end

  defp cutoff do
    DateTime.utc_now() |> Timex.shift(days: -@cutoff)
  end
end
