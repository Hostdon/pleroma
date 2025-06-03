# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.EmbedControllerTest do
  use Pleroma.Web.ConnCase, async: false
  import Pleroma.Factory

  test "/embed", %{conn: conn} do
    activity = insert(:note_activity)

    resp =
      conn
      |> get("/embed/#{activity.id}")
      |> response(200)

    object = Pleroma.Object.get_by_ap_id(activity.data["object"])

    assert String.contains?(resp, object.data["content"])
  end

  test "/embed with a restricted post", %{conn: conn} do
    activity = insert(:note_activity)
    clear_config([:restrict_unauthenticated, :activities, :local], true)

    conn
    |> get("/embed/#{activity.id}")
    |> response(401)
  end

  test "/embed with a private post", %{conn: conn} do
    user = insert(:user)

    {:ok, activity} =
      Pleroma.Web.CommonAPI.post(user, %{
        status: "Mega ultra chicken status: #fried",
        visibility: "private"
      })

    conn
    |> get("/embed/#{activity.id}")
    |> response(401)
  end
end
