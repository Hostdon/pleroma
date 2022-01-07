# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidator
  alias Pleroma.Web.ActivityPub.Utils

  import Pleroma.Factory

  describe "Notes" do
    setup do
      user = insert(:user)

      note = %{
        "id" => Utils.generate_activity_id(),
        "type" => "Note",
        "actor" => user.ap_id,
        "to" => [user.follower_address],
        "cc" => [],
        "content" => "Hellow this is content.",
        "context" => "xxx",
        "summary" => "a post"
      }

      %{user: user, note: note}
    end

    test "a basic note validates", %{note: note} do
      %{valid?: true} = ArticleNotePageValidator.cast_and_validate(note)
    end

    test "a note with a remote replies collection should validate", _ do
      insert(:user, %{ap_id: "https://bookwyrm.com/user/TestUser"})
      collection = File.read!("test/fixtures/bookwyrm-replies-collection.json")

      Tesla.Mock.mock(fn %{
                           method: :get,
                           url: "https://bookwyrm.com/user/TestUser/review/17/replies?page=1"
                         } ->
        %Tesla.Env{
          status: 200,
          body: collection,
          headers: HttpRequestMock.activitypub_object_headers()
        }
      end)

      note = Jason.decode!(File.read!("test/fixtures/bookwyrm-article.json"))

      %{valid?: true, changes: %{replies: ["https://bookwyrm.com/user/TestUser/status/18"]}} =
        ArticleNotePageValidator.cast_and_validate(note)
    end
  end
end
