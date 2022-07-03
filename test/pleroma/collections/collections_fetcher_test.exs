defmodule Akkoma.Collections.FetcherTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Akkoma.Collections.Fetcher

  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "it should extract items from an embedded array in a Collection" do
    unordered_collection =
      "test/fixtures/collections/unordered_array.json"
      |> File.read!()

    ap_id = "https://example.com/collection/ordered_array"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^ap_id
      } ->
        %Tesla.Env{
          status: 200,
          body: unordered_collection,
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, objects} = Fetcher.fetch_collection_by_ap_id(ap_id)
    assert [%{"type" => "Create"}, %{"type" => "Like"}] = objects
  end

  test "it should extract items from an embedded array in an OrderedCollection" do
    ordered_collection =
      "test/fixtures/collections/ordered_array.json"
      |> File.read!()

    ap_id = "https://example.com/collection/ordered_array"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^ap_id
      } ->
        %Tesla.Env{
          status: 200,
          body: ordered_collection,
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, objects} = Fetcher.fetch_collection_by_ap_id(ap_id)
    assert [%{"type" => "Create"}, %{"type" => "Like"}] = objects
  end

  test "it should extract items from an referenced first page in a Collection" do
    unordered_collection =
      "test/fixtures/collections/unordered_page_reference.json"
      |> File.read!()

    first_page =
      "test/fixtures/collections/unordered_page_first.json"
      |> File.read!()

    second_page =
      "test/fixtures/collections/unordered_page_second.json"
      |> File.read!()

    ap_id = "https://example.com/collection/unordered_page_reference"
    first_page_id = "https://example.com/collection/unordered_page_reference?page=1"
    second_page_id = "https://example.com/collection/unordered_page_reference?page=2"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^ap_id
      } ->
        %Tesla.Env{
          status: 200,
          body: unordered_collection,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^first_page_id
      } ->
        %Tesla.Env{
          status: 200,
          body: first_page,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^second_page_id
      } ->
        %Tesla.Env{
          status: 200,
          body: second_page,
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, objects} = Fetcher.fetch_collection_by_ap_id(ap_id)
    assert [%{"type" => "Create"}, %{"type" => "Like"}] = objects
  end

  test "it should stop fetching when we hit :max_collection_objects" do
    clear_config([:activitypub, :max_collection_objects], 1)

    unordered_collection =
      "test/fixtures/collections/unordered_page_reference.json"
      |> File.read!()

    first_page =
      "test/fixtures/collections/unordered_page_first.json"
      |> File.read!()

    second_page =
      "test/fixtures/collections/unordered_page_second.json"
      |> File.read!()

    ap_id = "https://example.com/collection/unordered_page_reference"
    first_page_id = "https://example.com/collection/unordered_page_reference?page=1"
    second_page_id = "https://example.com/collection/unordered_page_reference?page=2"

    Tesla.Mock.mock(fn
      %{
        method: :get,
        url: ^ap_id
      } ->
        %Tesla.Env{
          status: 200,
          body: unordered_collection,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^first_page_id
      } ->
        %Tesla.Env{
          status: 200,
          body: first_page,
          headers: [{"content-type", "application/activity+json"}]
        }

      %{
        method: :get,
        url: ^second_page_id
      } ->
        %Tesla.Env{
          status: 200,
          body: second_page,
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    {:ok, objects} = Fetcher.fetch_collection_by_ap_id(ap_id)
    assert [%{"type" => "Create"}] = objects
  end
end
