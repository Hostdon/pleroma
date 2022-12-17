defmodule Pleroma.ElasticsearchMock do
  @behaviour Elasticsearch.API

  @impl true
  def request(_config, :get, "/posts/1", _data, _opts) do
    {:ok,
     %HTTPoison.Response{
       status_code: 404,
       body: %{
         "status" => "not_found"
       }
     }}
  end
end
