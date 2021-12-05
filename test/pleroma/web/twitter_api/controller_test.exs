# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.ControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Factory

  describe "POST /api/qvitter/statuses/notifications/read" do
    test "without valid credentials", %{conn: conn} do
      conn = post(conn, "/api/qvitter/statuses/notifications/read", %{"latest_id" => 1_234_567})
      assert json_response(conn, 403) == %{"error" => "Invalid credentials."}
    end

    test "with credentials, without any params" do
      %{conn: conn} = oauth_access(["write:notifications"])

      conn = post(conn, "/api/qvitter/statuses/notifications/read")

      assert json_response(conn, 400) == %{
               "error" => "You need to specify latest_id",
               "request" => "/api/qvitter/statuses/notifications/read"
             }
    end

    test "with credentials, with params" do
      %{user: current_user, conn: conn} =
        oauth_access(["read:notifications", "write:notifications"])

      other_user = insert(:user)

      {:ok, _activity} =
        CommonAPI.post(other_user, %{
          status: "Hey @#{current_user.nickname}"
        })

      response_conn =
        conn
        |> get("/api/v1/notifications")

      [notification] = json_response(response_conn, 200)

      assert notification["pleroma"]["is_seen"] == false

      response_conn =
        conn
        |> post("/api/qvitter/statuses/notifications/read", %{"latest_id" => notification["id"]})

      [notification] = response = json_response(response_conn, 200)

      assert length(response) == 1

      assert notification["pleroma"]["is_seen"] == true
    end
  end

  describe "GET /api/account/confirm_email/:id/:token" do
    setup do
      {:ok, user} =
        insert(:user)
        |> User.confirmation_changeset(set_confirmation: false)
        |> Repo.update()

      refute user.is_confirmed

      [user: user]
    end

    test "it redirects to root url", %{conn: conn, user: user} do
      conn = get(conn, "/api/account/confirm_email/#{user.id}/#{user.confirmation_token}")

      assert 302 == conn.status
    end

    test "it confirms the user account", %{conn: conn, user: user} do
      get(conn, "/api/account/confirm_email/#{user.id}/#{user.confirmation_token}")

      user = User.get_cached_by_id(user.id)

      assert user.is_confirmed
      refute user.confirmation_token
    end

    test "it returns 500 if user cannot be found by id", %{conn: conn, user: user} do
      conn = get(conn, "/api/account/confirm_email/0/#{user.confirmation_token}")

      assert 500 == conn.status
    end

    test "it returns 500 if token is invalid", %{conn: conn, user: user} do
      conn = get(conn, "/api/account/confirm_email/#{user.id}/wrong_token")

      assert 500 == conn.status
    end
  end

  describe "GET /api/oauth_tokens" do
    setup do
      token = insert(:oauth_token) |> Repo.preload(:user)

      %{token: token}
    end

    test "renders list", %{token: token} do
      response =
        build_conn()
        |> assign(:user, token.user)
        |> get("/api/oauth_tokens")

      keys =
        json_response(response, 200)
        |> hd()
        |> Map.keys()

      assert keys -- ["id", "app_name", "valid_until"] == []
    end

    test "revoke token", %{token: token} do
      response =
        build_conn()
        |> assign(:user, token.user)
        |> delete("/api/oauth_tokens/#{token.id}")

      tokens = Token.get_user_tokens(token.user)

      assert tokens == []
      assert response.status == 201
    end
  end
end
