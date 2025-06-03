defmodule Pleroma.Workers.NodeInfoFetcherWorker do
  use Pleroma.Workers.WorkerHelper,
    queue: "nodeinfo_fetcher",
    unique: [
      keys: [:op, :source_url],
      # old jobs still get pruned after a short while
      period: :infinity,
      states: Oban.Job.states()
    ]

  alias Oban.Job
  alias Pleroma.Instances.Instance

  def enqueue(op, %{"source_url" => ap_id} = params, worker_args) do
    # reduce to base url to avoid enqueueing unneccessary duplicates
    domain =
      ap_id
      |> URI.parse()
      |> URI.merge("/")

    if Instance.needs_update(domain) do
      do_enqueue(op, %{params | "source_url" => URI.to_string(domain)}, worker_args)
    else
      :ok
    end
  end

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
