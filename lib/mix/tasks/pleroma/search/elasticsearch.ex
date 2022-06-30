defmodule Mix.Tasks.Pleroma.Search.Elasticsearch do
  alias Mix.Tasks.Elasticsearch.Build
  import Mix.Pleroma

  def run(["index" | args]) do
    start_pleroma()
    Build.run(args)
  end
end
