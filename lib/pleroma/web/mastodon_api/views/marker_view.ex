# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerView do
  use Pleroma.Web, :view

  def render("markers.json", %{markers: markers}) do
    Map.new(markers, fn m ->
      {m.timeline,
       %{
         last_read_id: m.last_read_id,
         version: m.lock_version,
         updated_at: NaiveDateTime.to_iso8601(m.updated_at),
         pleroma: %{
           unread_count: m.unread_count
         }
       }}
    end)
  end
end
