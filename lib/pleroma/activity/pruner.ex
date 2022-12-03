defmodule Pleroma.Activity.Pruner do
  @moduledoc """
  Prunes activities from the database.
  """
  @cutoff 30

  alias Pleroma.Activity
  alias Pleroma.Repo
  import Ecto.Query

  def prune_deletes do
    before_time = cutoff()

    from(a in Activity,
      where: fragment("?->>'type' = ?", a.data, "Delete") and a.inserted_at < ^before_time
    )
    |> Repo.delete_all(timeout: :infinity)
  end

  def prune_undos do
    before_time = cutoff()

    from(a in Activity,
      where: fragment("?->>'type' = ?", a.data, "Undo") and a.inserted_at < ^before_time
    )
    |> Repo.delete_all(timeout: :infinity)
  end

  def prune_removes do
    before_time = cutoff()

    from(a in Activity,
      where: fragment("?->>'type' = ?", a.data, "Remove") and a.inserted_at < ^before_time
    )
    |> Repo.delete_all(timeout: :infinity)
  end

  def prune_stale_follow_requests do
    before_time = cutoff()

    from(a in Activity,
      where:
        fragment("?->>'type' = ?", a.data, "Follow") and a.inserted_at < ^before_time and
          fragment("?->>'state' = ?", a.data, "reject")
    )
    |> Repo.delete_all(timeout: :infinity)
  end

  defp cutoff do
    DateTime.utc_now() |> Timex.shift(days: -@cutoff)
  end
end
