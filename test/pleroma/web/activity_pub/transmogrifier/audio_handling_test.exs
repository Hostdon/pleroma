# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.AudioHandlingTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  test "Funkwhale Audio object" do
    Tesla.Mock.mock(fn
      %{url: "https://channels.tests.funkwhale.audio/federation/actors/compositions"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/tesla_mock/funkwhale_channel.json"),
          headers: HttpRequestMock.activitypub_object_headers()
        }
    end)

    data = File.read!("test/fixtures/tesla_mock/funkwhale_create_audio.json") |> Jason.decode!()

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert object = Object.normalize(activity, fetch: false)

    assert object.data["to"] == ["https://www.w3.org/ns/activitystreams#Public"]

    assert object.data["cc"] == [
             "https://channels.tests.funkwhale.audio/federation/actors/compositions/followers"
           ]

    assert object.data["url"] == "https://channels.tests.funkwhale.audio/library/tracks/74"

    assert object.data["attachment"] == [
             %{
               "mediaType" => "audio/ogg",
               "type" => "Link",
               "url" => [
                 %{
                   "href" =>
                     "https://channels.tests.funkwhale.audio/api/v1/listen/3901e5d8-0445-49d5-9711-e096cf32e515/?upload=42342395-0208-4fee-a38d-259a6dae0871&download=false",
                   "mediaType" => "audio/ogg",
                   "type" => "Link"
                 }
               ]
             }
           ]
  end
end
