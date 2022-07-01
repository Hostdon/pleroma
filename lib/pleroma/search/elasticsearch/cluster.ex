defmodule Pleroma.Search.Elasticsearch.Cluster do
  @moduledoc false
  use Elasticsearch.Cluster, otp_app: :pleroma
end
