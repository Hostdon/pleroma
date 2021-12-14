defmodule Pleroma.Elasticsearch do
  alias Pleroma.Activity
  alias Pleroma.Elasticsearch.DocumentMappings
  alias Pleroma.Config

  defp url do
    Config.get([:elasticsearch, :url])
  end

  def put_by_id(id) do
    id
    |> Activity.get_by_id_with_object()
    |> maybe_put_into_elasticsearch()
  end

  def maybe_put_into_elasticsearch({:ok, activity}) do
    maybe_put_into_elasticsearch(activity)
  end

  def maybe_put_into_elasticsearch(%{data: %{"type" => "Create"}, object: %{data: %{"type" => "Note"}}} = activity) do
    if Config.get([:search, :provider]) == Pleroma.Search.Elasticsearch do
      actor = Pleroma.Activity.user_actor(activity)

      activity
      |> Map.put(:user_actor, actor)
      |> put()
    end
  end

  def maybe_put_into_elasticsearch(_) do
    {:ok, :skipped}
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
      |> Enum.filter(fn x ->
        t = x.object
        |> Map.get(:data, %{})
        |> Map.get("type", "")
        t == "Note"
      end)
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

  def bulk_post(data, :users) do
    d =
      data
      |> Enum.map(fn d ->
        [
          %{index: %{_id: DocumentMappings.User.id(d)}},
          DocumentMappings.User.encode(d)
        ]
      end)
      |> List.flatten()

    Elastix.Bulk.post(
      url(),
      d,
      index: "users",
      type: "user"
    )
  end

  def bulk_post(data, :hashtags) do
    d =
      data
      |> Enum.map(fn d ->
        [
          %{index: %{_id: DocumentMappings.Hashtag.id(d)}},
          DocumentMappings.Hashtag.encode(d)
        ]
      end)
      |> List.flatten()

    Elastix.Bulk.post(
      url(),
      d,
      index: "hashtags",
      type: "hashtag"
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
