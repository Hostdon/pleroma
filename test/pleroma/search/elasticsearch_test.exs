# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Search.ElasticsearchTest do
  require Pleroma.Constants

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory
  import Tesla.Mock
  import Mock

  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.SearchIndexingWorker

  describe "elasticsearch" do
    setup do
      clear_config([Pleroma.Search, :module], Pleroma.Search.Elasticsearch)
      clear_config([Pleroma.Search.Elasticsearch.Cluster, :api], Pleroma.ElasticsearchMock)
    end

    setup_with_mocks(
      [
        {Pleroma.Search.Elasticsearch, [:passthrough],
         [
           add_to_index: fn a -> passthrough([a]) end,
           remove_from_index: fn a -> passthrough([a]) end
         ]},
        {Elasticsearch, [:passthrough],
         [
           put_document: fn _, _, _ -> :ok end,
           delete_document: fn _, _, _ -> :ok end
         ]}
      ],
      context,
      do: {:ok, context}
    )

    test "indexes a local post on creation" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "guys i just don't wanna leave the swamp",
          visibility: "public"
        })

      args = %{"op" => "add_to_index", "activity" => activity.id}

      assert_enqueued(
        worker: SearchIndexingWorker,
        args: args
      )

      assert :ok = perform_job(SearchIndexingWorker, args)

      assert_called(Pleroma.Search.Elasticsearch.add_to_index(activity))
    end

    test "doesn't index posts that are not public" do
      user = insert(:user)

      Enum.each(["private", "direct"], fn visibility ->
        {:ok, activity} =
          CommonAPI.post(user, %{
            status: "guys i just don't wanna leave the swamp",
            visibility: visibility
          })

        args = %{"op" => "add_to_index", "activity" => activity.id}

        assert_enqueued(worker: SearchIndexingWorker, args: args)
        assert :ok = perform_job(SearchIndexingWorker, args)

        assert_not_called(Elasticsearch.put_document(:_))
      end)

      history = call_history(Pleroma.Search.Elasticsearch)
      assert Enum.count(history) == 2
    end

    test "deletes posts from index when deleted locally" do
      user = insert(:user)

      mock_global(fn
        %{method: :put, url: "http://127.0.0.1:7700/indexes/objects/documents", body: body} ->
          assert match?(
                   [%{"content" => "guys i just don&#39;t wanna leave the swamp"}],
                   Jason.decode!(body)
                 )

          json(%{updateId: 1})

        %{method: :delete, url: "http://127.0.0.1:7700/indexes/objects/documents/" <> id} ->
          assert String.length(id) > 1
          json(%{updateId: 2})
      end)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "guys i just don't wanna leave the swamp",
          visibility: "public"
        })

      args = %{"op" => "add_to_index", "activity" => activity.id}
      assert_enqueued(worker: SearchIndexingWorker, args: args)
      assert :ok = perform_job(SearchIndexingWorker, args)

      {:ok, _} = CommonAPI.delete(activity.id, user)

      delete_args = %{"op" => "remove_from_index", "object" => activity.object.id}
      assert_enqueued(worker: SearchIndexingWorker, args: delete_args)
      assert :ok = perform_job(SearchIndexingWorker, delete_args)

      assert_called(Pleroma.Search.Elasticsearch.remove_from_index(:_))
    end
  end
end
