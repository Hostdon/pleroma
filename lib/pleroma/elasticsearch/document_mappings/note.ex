defmodule Pleroma.Elasticsearch.DocumentMappings.Activity do
  alias Pleroma.Object

  def id(obj), do: obj.id
  def encode(%{object: %{data: %{ "type" => "Note" }}} = activity) do
    %{
        user: activity.user_actor.nickname,
        content: activity.object.data["content"],
        instance: URI.parse(activity.user_actor.ap_id).host,
        hashtags: Object.hashtags(activity.object)
    }
  end
end
