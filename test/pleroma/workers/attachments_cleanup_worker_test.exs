# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.AttachmentsCleanupWorkerTest do
  use Pleroma.DataCase, async: false
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  alias Pleroma.Object
  alias Pleroma.Workers.AttachmentsCleanupWorker
  alias Pleroma.Tests.ObanHelpers

  setup do
    clear_config([:instance, :cleanup_attachments], true)

    file = %Plug.Upload{
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    user = insert(:user)

    {:ok, %Pleroma.Object{} = attachment} =
      Pleroma.Web.ActivityPub.ActivityPub.upload(file, actor: user.ap_id)

    {:ok, attachment: attachment, user: user}
  end

  test "does not enqueue remote post" do
    remote_data = %{
      "id" => "https://remote.example/obj/123",
      "actor" => "https://remote.example/user/1",
      "content" => "content",
      "attachment" => [
        %{
          "type" => "Document",
          "mediaType" => "image/png",
          "name" => "marvellous image",
          "url" => "https://remote.example/files/image.png"
        }
      ]
    }

    assert {:ok, :skip} = AttachmentsCleanupWorker.enqueue_if_needed(remote_data)
  end

  test "enqueues local post", %{attachment: attachment, user: user} do
    local_url = Pleroma.Web.Endpoint.url()

    local_data = %{
      "id" => local_url <> "/obj/123",
      "actor" => user.ap_id,
      "content" => "content",
      "attachment" => [attachment.data]
    }

    assert {:ok, %Oban.Job{}} = AttachmentsCleanupWorker.enqueue_if_needed(local_data)
  end

  test "doesn't delete immediately", %{attachment: attachment, user: user} do
    delay = 6000
    clear_config([:instance, :cleanup_attachments_delay], delay)

    note = insert(:note, %{user: user, data: %{"attachment" => [attachment.data]}})

    uploads_dir = Pleroma.Config.get!([Pleroma.Uploaders.Local, :uploads])
    %{"url" => [%{"href" => href}]} = attachment.data
    path = "#{uploads_dir}/#{Path.basename(href)}"

    assert File.exists?(path)

    Object.delete(note)
    Process.sleep(2000)

    assert File.exists?(path)

    ObanHelpers.perform(all_enqueued(worker: Pleroma.Workers.AttachmentsCleanupWorker))

    assert Object.get_by_id(note.id).data["deleted"]
    assert Object.get_by_id(attachment.id) == nil
    refute File.exists?(path)
  end
end
