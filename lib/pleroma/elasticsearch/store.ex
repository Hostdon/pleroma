defmodule Pleroma.Elasticsearch do
  alias Pleroma.Activity
  alias Pleroma.Elasticsearch.DocumentMappings

  defp url do
    Pleroma.Config.get([:elasticsearch, :url])
  end

  def put(%Activity{} = activity) do
    Elastix.Document.index(
      url(),
      "activities",
      "activity",
      DocumentMappings.Activity.id(activity),
      DocumentMappings.Activity.encode(activity)
    )
  end

  def bulk_post(data, :activities) do
    d =
      data
      |> Enum.map(fn d ->
        [
          %{index: %{_id: DocumentMappings.Activity.id(d)}},
          DocumentMappings.Activity.encode(d)
        ]
      end)
      |> List.flatten()

    Elastix.Bulk.post(
      url(),
      d,
      index: "activities",
      type: "activity"
    )
  end

  def search_activities(q) do
    Elastix.Search.search(
      url(),
      "activities",
      ["activity"],
      q
    )
  end
end
