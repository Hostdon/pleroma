# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorkerTest do
  use Pleroma.DataCase, async: false
  use Oban.Testing, repo: Pleroma.Repo
  @moduletag :mocked

  import ExUnit.CaptureLog
  import Mock
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Workers.ReceiverWorker

  test "it ignores MRF reject" do
    user = insert(:user, local: false)
    params = insert(:note, user: user, data: %{"id" => user.ap_id <> "/note/1"}).data

    with_mock Pleroma.Web.ActivityPub.Transmogrifier,
      handle_incoming: fn _ -> {:reject, "MRF"} end do
      assert {:cancel, "MRF"} =
               ReceiverWorker.perform(%Oban.Job{
                 args: %{"op" => "incoming_ap_doc", "params" => params}
               })
    end
  end

  test "it errors on receiving local documents" do
    actor = insert(:user, local: true)
    recipient = insert(:user, local: true)

    to = [recipient.ap_id]
    cc = []

    params = %{
      "@context" => ["https://www.w3.org/ns/activitystreams"],
      "type" => "Create",
      "id" => Utils.generate_activity_id(),
      "to" => to,
      "cc" => cc,
      "actor" => actor.ap_id,
      "object" => %{
        "type" => "Note",
        "to" => to,
        "cc" => cc,
        "content" => "It's a note",
        "attributedTo" => actor.ap_id,
        "id" => Utils.generate_object_id()
      }
    }

    assert capture_log(fn ->
             assert {:discard, :origin_containment_failed} ==
                      ReceiverWorker.perform(%Oban.Job{
                        args: %{"op" => "incoming_ap_doc", "params" => params}
                      })
           end) =~ "[alert] Received incoming AP doc with valid signature for local actor"
  end
end
