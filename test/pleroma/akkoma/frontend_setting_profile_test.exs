defmodule Pleroma.Akkoma.FrontendSettingsProfileTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo
  alias Pleroma.Akkoma.FrontendSettingsProfile

  import Pleroma.Factory

  describe "changeset/2" do
    test "valid" do
      user = insert(:user)
      frontend_name = "test"
      profile_name = "test"
      settings = %{"test" => "test"}
      struct = %FrontendSettingsProfile{}

      attrs = %{
        user_id: user.id,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: settings,
        version: 1
      }

      assert %{valid?: true} = FrontendSettingsProfile.changeset(struct, attrs)
    end

    test "when settings is too long" do
      clear_config([:instance, :max_frontend_settings_json_chars], 10)
      user = insert(:user)
      frontend_name = "test"
      profile_name = "test"
      settings = %{"verylong" => "verylongoops"}
      struct = %FrontendSettingsProfile{}

      attrs = %{
        user_id: user.id,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: settings,
        version: 1
      }

      assert %{valid?: false, errors: [settings: {"is too long", _}]} =
               FrontendSettingsProfile.changeset(struct, attrs)
    end

    test "when frontend name is too short" do
      user = insert(:user)
      frontend_name = ""
      profile_name = "test"
      settings = %{"test" => "test"}
      struct = %FrontendSettingsProfile{}

      attrs = %{
        user_id: user.id,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: settings,
        version: 1
      }

      assert %{valid?: false, errors: [frontend_name: {"can't be blank", _}]} =
               FrontendSettingsProfile.changeset(struct, attrs)
    end

    test "when profile name is too short" do
      user = insert(:user)
      frontend_name = "test"
      profile_name = ""
      settings = %{"test" => "test"}
      struct = %FrontendSettingsProfile{}

      attrs = %{
        user_id: user.id,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: settings,
        version: 1
      }

      assert %{valid?: false, errors: [profile_name: {"can't be blank", _}]} =
               FrontendSettingsProfile.changeset(struct, attrs)
    end

    test "when version is negative" do
      user = insert(:user)
      frontend_name = "test"
      profile_name = "test"
      settings = %{"test" => "test"}
      struct = %FrontendSettingsProfile{}

      attrs = %{
        user_id: user.id,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: settings,
        version: -1
      }

      assert %{valid?: false, errors: [version: {"must be greater than %{number}", _}]} =
               FrontendSettingsProfile.changeset(struct, attrs)
    end
  end

  describe "create_or_update/2" do
    test "it should create a new record" do
      user = insert(:user)
      frontend_name = "test"
      profile_name = "test"
      settings = %{"test" => "test"}

      assert {:ok, %FrontendSettingsProfile{}} =
               FrontendSettingsProfile.create_or_update(
                 user,
                 frontend_name,
                 profile_name,
                 settings,
                 1
               )
    end

    test "it should update a record" do
      user = insert(:user)
      frontend_name = "test"
      profile_name = "test"

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: %{"test" => "test"},
        version: 1
      )

      settings = %{"test" => "test2"}

      assert {:ok, %FrontendSettingsProfile{settings: ^settings}} =
               FrontendSettingsProfile.create_or_update(
                 user,
                 frontend_name,
                 profile_name,
                 settings,
                 2
               )
    end
  end

  describe "get_all_by_user_and_frontend_name/2" do
    test "it should return all records" do
      user = insert(:user)
      frontend_name = "test"

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: frontend_name,
        profile_name: "profileA",
        settings: %{"test" => "test"},
        version: 1
      )

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: frontend_name,
        profile_name: "profileB",
        settings: %{"test" => "test"},
        version: 1
      )

      assert [%FrontendSettingsProfile{profile_name: "profileA"}, %{profile_name: "profileB"}] =
               FrontendSettingsProfile.get_all_by_user_and_frontend_name(user, frontend_name)
    end
  end

  describe "get_by_user_and_frontend_name_and_profile_name/3" do
    test "it should return a record" do
      user = insert(:user)
      frontend_name = "test"
      profile_name = "profileA"

      insert(:frontend_setting_profile,
        user: user,
        frontend_name: frontend_name,
        profile_name: profile_name,
        settings: %{"test" => "test"},
        version: 1
      )

      assert %FrontendSettingsProfile{profile_name: "profileA"} =
               FrontendSettingsProfile.get_by_user_and_frontend_name_and_profile_name(
                 user,
                 frontend_name,
                 profile_name
               )
    end
  end
end
