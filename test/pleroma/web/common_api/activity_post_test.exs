# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityPostTest do
  use Pleroma.Web.ConnCase, async: false
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  setup do: oauth_access(["write:statuses"])

  defp test_dm_addressing(conn, to) do
    resp =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/statuses", %{
        "status" => "@#{to.nickname} hi!",
        "visibility" => "direct"
      })
      |> json_response_and_validate_schema(200)

    assert Enum.any?(resp["mentions"], fn %{"id" => id} -> id == to.id end)
  end

  describe "addresses mentioned user" do
    test "when no dot in name", %{conn: conn} do
      addr = insert(:user, local: false, nickname: "nix@example.org")
      test_dm_addressing(conn, addr)
    end

    test "when dot in name", %{conn: conn} do
      addr = insert(:user, local: false, nickname: "ly.nx@example.org")
      test_dm_addressing(conn, addr)
    end
  end
end
