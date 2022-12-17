defmodule Pleroma.Workers.Cron.PruneDatabaseWorker do
  @moduledoc """
  The worker to prune old data from the database.
  """
  require Logger
  use Oban.Worker, queue: "database_prune"

  alias Pleroma.Activity.Pruner, as: ActivityPruner
  alias Pleroma.Object.Pruner, as: ObjectPruner

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Pruning old data from the database")

    Logger.info("Pruning old deletes")
    ActivityPruner.prune_deletes()

    Logger.info("Pruning old follow requests")
    ActivityPruner.prune_stale_follow_requests()

    Logger.info("Pruning old undos")
    ActivityPruner.prune_undos()

    Logger.info("Pruning old removes")
    ActivityPruner.prune_removes()

    Logger.info("Pruning old tombstone delivery entries")
    ObjectPruner.prune_tombstoned_deliveries()

    Logger.info("Pruning old tombstones")
    ObjectPruner.prune_tombstones()

    :ok
  end
end
