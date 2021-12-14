defmodule Pleroma.Elasticsearch.DocumentMappings.User do
  def id(obj), do: obj.id

  def encode(%{actor_type: "Person"} = user) do
    %{
      timestamp: user.inserted_at,
      instance: URI.parse(user.ap_id).host,
      nickname: user.nickname,
      bio: user.bio,
      display_name: user.name
    }
  end
end
