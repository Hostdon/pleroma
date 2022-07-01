# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Search do
  use Mix.Task
  import Mix.Pleroma

  @shortdoc "Manages elasticsearch"

  def run(["import", "activities" | _rest]) do
    start_pleroma()

    Elasticsearch.Index.Bulk.upload(
      Pleroma.Search.Elasticsearch.Cluster,
      "activities",
      Pleroma.Config.get([Pleroma.Search.Elasticsearch.Cluster, :indexes, :activities])
    )
  end
end
