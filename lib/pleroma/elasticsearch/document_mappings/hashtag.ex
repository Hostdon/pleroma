defmodule Pleroma.Elasticsearch.DocumentMappings.Hashtag do
  def id(obj), do: obj.id

  def encode(hashtag) do
    %{
      hashtag: hashtag.name,
      timestamp: hashtag.inserted_at
    }
  end
end
