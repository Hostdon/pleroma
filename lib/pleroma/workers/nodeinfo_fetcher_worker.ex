defmodule Pleroma.Workers.NodeInfoFetcherWorker do
  use Pleroma.Workers.WorkerHelper, queue: "nodeinfo_fetcher"

  alias Oban.Job
  alias Pleroma.Instances.Instance

  @impl Oban.Worker
  def perform(%Job{
        args: %{"op" => "process", "source_url" => domain}
      }) do
    uri =
      domain
      |> URI.parse()
      |> URI.merge("/")

    Instance.update_metadata(uri)
  end
end
