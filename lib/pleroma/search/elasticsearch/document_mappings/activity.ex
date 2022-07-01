# Akkoma: A lightweight social networking server
# Copyright © 2022-2022 Akkoma Authors <https://git.ihatebeinga.live/IHBAGang/akkoma/>
# SPDX-License-Identifier: AGPL-3.0-only

defimpl Elasticsearch.Document, for: Pleroma.Activity do
  alias Pleroma.Object
  require Pleroma.Constants

  def id(obj), do: obj.id
  def routing(_), do: false

  def object_to_search_data(object) do
    # Only index public or unlisted Notes
    if not is_nil(object) and object.data["type"] == "Note" and
         not is_nil(object.data["content"]) and
         (Pleroma.Constants.as_public() in object.data["to"] or
            Pleroma.Constants.as_public() in object.data["cc"]) and
         String.length(object.data["content"]) > 1 do
      data = object.data

      content_str =
        case data["content"] do
          [nil | rest] -> to_string(rest)
          str -> str
        end

      content =
        with {:ok, scrubbed} <- FastSanitize.strip_tags(content_str),
             trimmed <- String.trim(scrubbed) do
          trimmed
        end

      if String.length(content) > 1 do
        {:ok, published, _} = DateTime.from_iso8601(data["published"])

        %{
          _timestamp: published,
          content: content,
          instance: URI.parse(object.data["actor"]).host,
          hashtags: Object.hashtags(object),
          user: Pleroma.User.get_cached_by_ap_id(object.data["actor"]).nickname
        }
      else
        %{}
      end
    else
      %{}
    end
  end

  def encode(activity) do
    object = Pleroma.Object.normalize(activity)
    object_to_search_data(object)
  end
end

defimpl Elasticsearch.Document, for: Pleroma.Object do
  def id(obj), do: obj.id
  def routing(_), do: false
  def encode(_), do: nil
end
