# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerViewTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Web.MastodonAPI.MarkerView
  import Pleroma.Factory

  # Mastodon API only accepts a specific subset of ISO 8061
  # (and we additionally truncate precision, eeventhough milliseconds are allowed)
  defp expected_date(full_timestamp) do
    full_timestamp
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> then(&(&1 <> ".000Z"))
  end

  test "returns markers" do
    marker1 = insert(:marker, timeline: "notifications", last_read_id: "17", unread_count: 5)
    marker2 = insert(:marker, timeline: "home", last_read_id: "42")

    assert MarkerView.render("markers.json", %{markers: [marker1, marker2]}) == %{
             "home" => %{
               last_read_id: "42",
               updated_at: expected_date(marker2.updated_at),
               version: 0,
               pleroma: %{unread_count: 0}
             },
             "notifications" => %{
               last_read_id: "17",
               updated_at: expected_date(marker1.updated_at),
               version: 0,
               pleroma: %{unread_count: 5}
             }
           }
  end
end
