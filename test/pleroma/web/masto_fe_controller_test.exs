defmodule Pleroma.Web.MastoFEControllerTest do
  use Pleroma.Web.ConnCase, async: true
  alias Pleroma.Web.MastodonAPI.AuthController

  describe "index/2 (main page)" do
    test "GET /web/ (glitch-soc)" do
      clear_config([:frontends, :mastodon], %{"name" => "mastodon-fe"})

      {:ok, masto_app} = AuthController.local_mastofe_app()
      user = Pleroma.Factory.insert(:user)
      token = Pleroma.Factory.insert(:oauth_token, app: masto_app, user: user)
      %{conn: conn} = oauth_access(["read", "write"], oauth_token: token, user: user)

      resp =
        conn
        |> get("/web/getting-started")
        |> html_response(200)

      assert resp =~ "glitch"
    end

    test "GET /web/ (fedibird)" do
      clear_config([:frontends, :mastodon], %{"name" => "fedibird-fe"})

      {:ok, masto_app} = AuthController.local_mastofe_app()
      user = Pleroma.Factory.insert(:user)
      token = Pleroma.Factory.insert(:oauth_token, app: masto_app, user: user)
      %{conn: conn} = oauth_access(["read", "write"], oauth_token: token, user: user)

      resp =
        conn
        |> get("/web/getting-started")
        |> html_response(200)

      refute resp =~ "glitch"
    end
  end
end
