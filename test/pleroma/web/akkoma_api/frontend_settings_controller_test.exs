defmodule Pleroma.Web.AkkomaAPI.FrontendSettingsControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory
  alias Pleroma.Akkoma.FrontendSettingsProfile

  describe "GET /api/v1/akkoma/frontend_settings/:frontend_name" do
    test "it returns a list of profiles" do
      %{conn: conn, user: user} = oauth_access(["read"])

      insert(:frontend_setting_profile, user: user, frontend_name: "test", profile_name: "test1")
      insert(:frontend_setting_profile, user: user, frontend_name: "test", profile_name: "test2")

      response =
        conn
        |> get("/api/v1/akkoma/frontend_settings/test")
        |> json_response_and_validate_schema(200)

      assert response == [
               %{"name" => "test1", "version" => 1},
               %{"name" => "test2", "version" => 1}
             ]
    end
  end

  describe "GET /api/v1/akkoma/frontend_settings/:frontend_name/:profile_name" do
    test "it returns 404 if not found" do
      %{conn: conn} = oauth_access(["read"])

      conn
      |> get("/api/v1/akkoma/frontend_settings/unknown_frontend/unknown_profile")
      |> json_response_and_validate_schema(404)
    end

    test "it returns 200 if found" do
      %{conn: conn, user: user} = oauth_access(["read"])

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: "test",
        profile_name: "test1",
        settings: %{"test" => "test"}
      )

      response =
        conn
        |> get("/api/v1/akkoma/frontend_settings/test/test1")
        |> json_response_and_validate_schema(200)

      assert response == %{"settings" => %{"test" => "test"}, "version" => 1}
    end
  end

  describe "PUT /api/v1/akkoma/frontend_settings/:frontend_name/:profile_name" do
    test "puts a config" do
      %{conn: conn, user: user} = oauth_access(["write"])
      settings = %{"test" => "test2"}

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/v1/akkoma/frontend_settings/test/test1", %{
          "settings" => settings,
          "version" => 1
        })
        |> json_response_and_validate_schema(200)

      assert response == settings

      assert %FrontendSettingsProfile{settings: ^settings} =
               FrontendSettingsProfile.get_by_user_and_frontend_name_and_profile_name(
                 user,
                 "test",
                 "test1"
               )
    end

    test "refuses to overwrite a newer config" do
      %{conn: conn, user: user} = oauth_access(["write"])

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: "test",
        profile_name: "test1",
        settings: %{"test" => "test"},
        version: 2
      )

      conn
      |> put_req_header("content-type", "application/json")
      |> put("/api/v1/akkoma/frontend_settings/test/test1", %{
        "settings" => %{"test" => "test2"},
        "version" => 1
      })
      |> json_response_and_validate_schema(422)
    end
  end

  describe "DELETE /api/v1/akkoma/frontend_settings/:frontend_name/:profile_name" do
    test "deletes a config" do
      %{conn: conn, user: user} = oauth_access(["write"])

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: "test",
        profile_name: "test1",
        settings: %{"test" => "test"},
        version: 2
      )

      conn
      |> delete("/api/v1/akkoma/frontend_settings/test/test1")
      |> json_response_and_validate_schema(200)

      assert FrontendSettingsProfile.get_by_user_and_frontend_name_and_profile_name(
               user,
               "test",
               "test1"
             ) == nil
    end
  end
end
