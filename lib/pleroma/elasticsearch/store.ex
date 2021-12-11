defmodule Pleroma.Elasticsearch do
  alias Pleroma.Activity
  alias Pleroma.Elasticsearch.DocumentMappings

  @searchable [
    "hashtag", "instance", "user"
  ]

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
    d = data
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

  defp parse_term(t) do
    if String.contains?(t, ":") and !String.starts_with?(t, "\"") do
      [field, query] = String.split(t, ":")
      if Enum.member?(@searchable, field) do
        {field, query}
      else
        {"content", query}
      end
    else
        {"content", t}
    end
  end

  defp search_user(params, q) do
    if q["user"] != nil do
      params ++ [%{match: %{user: %{
        query: Enum.join(q["user"], " "),
        operator: "OR"
      }}}]
    else
      params
    end
  end

  defp search_instance(params, q) do
    if q["instance"] != nil do 
      params ++ [%{match: %{instance: %{
        query: Enum.join(q["instance"], " "),
        operator: "OR"
      }}}]
    else
      params
    end
  end

  defp search_content(params, q) do
    if q["content"] != nil do
      params ++ [%{match: %{content: %{
        query: Enum.join(q["content"], " "),
        operator: "AND"
      }}}]
    else
      params
    end
 end
 
  defp to_es(q) do
    []
    |> search_content(q)
    |> search_instance(q)
    |> search_user(q)
  end

  defp parse(query) do
    String.split(query, " ")
    |> Enum.map(&parse_term/1)
    |> Enum.reduce(%{}, fn {field, query}, acc ->
        Map.put(acc, field,
            Map.get(acc, field, []) ++ [query]
        )
    end)
    |> to_es()
  end
    
  def search(query) do
    q = %{query: %{
      bool: %{
        must: parse(query)
      }
    }}
    IO.inspect(q)
    Elastix.Search.search(
        url(),
        "activities",
        ["activity"],
        q
    )
  end
end
