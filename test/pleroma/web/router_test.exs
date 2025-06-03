defmodule Pleroma.Web.RouterTest do
  use Pleroma.DataCase
  use Mneme

  test "route prefix stability" do
    auto_assert(
      [
        "api",
        "main",
        "ostatus_subscribe",
        "oauth",
        "akkoma",
        "objects",
        "activities",
        "notice",
        "@:nickname",
        ":nickname",
        "users",
        "tags",
        "mailer",
        "inbox",
        "relay",
        "internal",
        ".well-known",
        "nodeinfo",
        "manifest.json",
        "web",
        "auth",
        "embed",
        "proxy",
        "phoenix",
        "test",
        "user_exists",
        "check_password"
      ] <- Pleroma.Web.Router.get_api_routes()
    )
  end
end
