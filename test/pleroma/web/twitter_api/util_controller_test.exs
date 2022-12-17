# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.UtilControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User

  import Pleroma.Factory
  import Mock

  setup do
    Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance])
  setup do: clear_config([:frontend_configurations, :pleroma_fe])

  describe "PUT /api/pleroma/notification_settings" do
    setup do: oauth_access(["write:accounts"])

    test "it updates notification settings", %{user: user, conn: conn} do
      conn
      |> put(
        "/api/pleroma/notification_settings?#{URI.encode_query(%{block_from_strangers: true})}"
      )
      |> json_response_and_validate_schema(:ok)

      user = refresh_record(user)

      assert %Pleroma.User.NotificationSetting{
               block_from_strangers: true,
               hide_notification_contents: false
             } == user.notification_settings
    end

    test "it updates notification settings to enable hiding contents", %{user: user, conn: conn} do
      conn
      |> put(
        "/api/pleroma/notification_settings?#{URI.encode_query(%{hide_notification_contents: 1})}"
      )
      |> json_response_and_validate_schema(:ok)

      user = refresh_record(user)

      assert %Pleroma.User.NotificationSetting{
               block_from_strangers: false,
               hide_notification_contents: true
             } == user.notification_settings
    end
  end

  describe "GET /api/pleroma/frontend_configurations" do
    test "returns everything in :pleroma, :frontend_configurations", %{conn: conn} do
      config = [
        frontend_a: %{
          x: 1,
          y: 2
        },
        frontend_b: %{
          z: 3
        }
      ]

      clear_config(:frontend_configurations, config)

      response =
        conn
        |> get("/api/pleroma/frontend_configurations")
        |> json_response_and_validate_schema(:ok)

      assert response == Jason.encode!(config |> Enum.into(%{})) |> Jason.decode!()
    end
  end

  describe "/api/pleroma/emoji" do
    test "returns json with custom emoji with tags", %{conn: conn} do
      emoji =
        conn
        |> get("/api/pleroma/emoji")
        |> json_response_and_validate_schema(200)

      assert Enum.all?(emoji, fn
               {_key,
                %{
                  "image_url" => url,
                  "tags" => tags
                }} ->
                 is_binary(url) and is_list(tags)
             end)
    end
  end

  describe "GET /api/pleroma/healthcheck" do
    setup do: clear_config([:instance, :healthcheck])

    test "returns 503 when healthcheck disabled", %{conn: conn} do
      clear_config([:instance, :healthcheck], false)

      response =
        conn
        |> get("/api/pleroma/healthcheck")
        |> json_response_and_validate_schema(503)

      assert response == %{}
    end

    test "returns 200 when healthcheck enabled and all ok", %{conn: conn} do
      clear_config([:instance, :healthcheck], true)

      with_mock Pleroma.Healthcheck,
        system_info: fn -> %Pleroma.Healthcheck{healthy: true} end do
        response =
          conn
          |> get("/api/pleroma/healthcheck")
          |> json_response_and_validate_schema(200)

        assert %{
                 "active" => _,
                 "healthy" => true,
                 "idle" => _,
                 "memory_used" => _,
                 "pool_size" => _
               } = response
      end
    end

    test "returns 503 when healthcheck enabled and health is false", %{conn: conn} do
      clear_config([:instance, :healthcheck], true)

      with_mock Pleroma.Healthcheck,
        system_info: fn -> %Pleroma.Healthcheck{healthy: false} end do
        response =
          conn
          |> get("/api/pleroma/healthcheck")
          |> json_response_and_validate_schema(503)

        assert %{
                 "active" => _,
                 "healthy" => false,
                 "idle" => _,
                 "memory_used" => _,
                 "pool_size" => _
               } = response
      end
    end
  end

  describe "POST /api/pleroma/disable_account" do
    setup do: oauth_access(["write:accounts"])

    test "with valid permissions and password, it disables the account", %{conn: conn, user: user} do
      response =
        conn
        |> post("/api/pleroma/disable_account?password=test")
        |> json_response_and_validate_schema(:ok)

      assert response == %{"status" => "success"}
      ObanHelpers.perform_all()

      user = User.get_cached_by_id(user.id)

      refute user.is_active
    end

    test "with valid permissions and invalid password, it returns an error", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> post("/api/pleroma/disable_account?password=test1")
        |> json_response_and_validate_schema(:ok)

      assert response == %{"error" => "Invalid password."}
      user = User.get_cached_by_id(user.id)

      assert user.is_active
    end
  end

  describe "POST /main/ostatus - remote_subscribe/2" do
    setup do: clear_config([:instance, :federating], true)

    test "renders subscribe form", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> post("/main/ostatus", %{"nickname" => user.nickname, "profile" => ""})
        |> response(:ok)

      refute response =~ "Could not find user"
      assert response =~ "Remotely follow #{user.nickname}"
    end

    test "renders subscribe form with error when user not found", %{conn: conn} do
      response =
        conn
        |> post("/main/ostatus", %{"nickname" => "nickname", "profile" => ""})
        |> response(:ok)

      assert response =~ "Could not find user"
      refute response =~ "Remotely follow"
    end

    test "it redirect to webfinger url", %{conn: conn} do
      user = insert(:user)
      user2 = insert(:user, ap_id: "shp@social.heldscal.la")

      conn =
        conn
        |> post("/main/ostatus", %{
          "user" => %{"nickname" => user.nickname, "profile" => user2.ap_id}
        })

      assert redirected_to(conn) ==
               "https://social.heldscal.la/main/ostatussub?profile=#{user.ap_id}"
    end

    test "it renders form with error when user not found", %{conn: conn} do
      user2 = insert(:user, ap_id: "shp@social.heldscal.la")

      response =
        conn
        |> post("/main/ostatus", %{"user" => %{"nickname" => "jimm", "profile" => user2.ap_id}})
        |> response(:ok)

      assert response =~ "Something went wrong."
    end
  end

  describe "POST /main/ostatus - remote_subscribe/2 - with statuses" do
    setup do: clear_config([:instance, :federating], true)

    test "renders subscribe form", %{conn: conn} do
      user = insert(:user)
      status = insert(:note_activity, %{user: user})
      status_id = status.id

      assert is_binary(status_id)

      response =
        conn
        |> post("/main/ostatus", %{"status_id" => status_id, "profile" => ""})
        |> response(:ok)

      refute response =~ "Could not find status"
      assert response =~ "Interacting with"
    end

    test "renders subscribe form with error when status not found", %{conn: conn} do
      response =
        conn
        |> post("/main/ostatus", %{"status_id" => "somerandomid", "profile" => ""})
        |> response(:ok)

      assert response =~ "Could not find status"
      refute response =~ "Interacting with"
    end

    test "it redirect to webfinger url", %{conn: conn} do
      user = insert(:user)
      status = insert(:note_activity, %{user: user})
      status_id = status.id
      status_ap_id = status.data["object"]

      assert is_binary(status_id)
      assert is_binary(status_ap_id)

      user2 = insert(:user, ap_id: "shp@social.heldscal.la")

      conn =
        conn
        |> post("/main/ostatus", %{
          "status" => %{"status_id" => status_id, "profile" => user2.ap_id}
        })

      assert redirected_to(conn) ==
               "https://social.heldscal.la/main/ostatussub?profile=#{status_ap_id}"
    end

    test "it renders form with error when status not found", %{conn: conn} do
      user2 = insert(:user, ap_id: "shp@social.heldscal.la")

      response =
        conn
        |> post("/main/ostatus", %{
          "status" => %{"status_id" => "somerandomid", "profile" => user2.ap_id}
        })
        |> response(:ok)

      assert response =~ "Something went wrong."
    end
  end

  describe "GET /main/ostatus - show_subscribe_form/2" do
    setup do: clear_config([:instance, :federating], true)

    test "it works with users", %{conn: conn} do
      user = insert(:user)

      response =
        conn
        |> get("/main/ostatus", %{"nickname" => user.nickname})
        |> response(:ok)

      refute response =~ "Could not find user"
      assert response =~ "Remotely follow #{user.nickname}"
    end

    test "it works with statuses", %{conn: conn} do
      user = insert(:user)
      status = insert(:note_activity, %{user: user})
      status_id = status.id

      assert is_binary(status_id)

      response =
        conn
        |> get("/main/ostatus", %{"status_id" => status_id})
        |> response(:ok)

      refute response =~ "Could not find status"
      assert response =~ "Interacting with"
    end
  end

  test "it returns new captcha", %{conn: conn} do
    with_mock Pleroma.Captcha,
      new: fn -> "test_captcha" end do
      resp =
        conn
        |> get("/api/pleroma/captcha")
        |> response(200)

      assert resp == "\"test_captcha\""
      assert called(Pleroma.Captcha.new())
    end
  end

  describe "POST /api/pleroma/change_email" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "hi", email: "test@test.com"})

      assert json_response_and_validate_schema(conn, 403) == %{
               "error" => "Insufficient permissions: write:accounts."
             }
    end

    test "with proper permissions and invalid password", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "hi", email: "test@test.com"})

      assert json_response_and_validate_schema(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with proper permissions, valid password and invalid email", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "test", email: "foobar"})

      assert json_response_and_validate_schema(conn, 200) == %{
               "error" => "Email has invalid format."
             }
    end

    test "with proper permissions, valid password and no email", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "test"})

      assert %{"error" => "Missing field: email."} = json_response_and_validate_schema(conn, 400)
    end

    test "with proper permissions, valid password and blank email, when instance requires user email",
         %{
           conn: conn
         } do
      orig_account_activation_required =
        Pleroma.Config.get([:instance, :account_activation_required])

      Pleroma.Config.put([:instance, :account_activation_required], true)

      on_exit(fn ->
        Pleroma.Config.put(
          [:instance, :account_activation_required],
          orig_account_activation_required
        )
      end)

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "test", email: ""})

      assert json_response_and_validate_schema(conn, 200) == %{"error" => "Email can't be blank."}
    end

    test "with proper permissions, valid password and blank email, when instance does not require user email",
         %{
           conn: conn
         } do
      orig_account_activation_required =
        Pleroma.Config.get([:instance, :account_activation_required])

      Pleroma.Config.put([:instance, :account_activation_required], false)

      on_exit(fn ->
        Pleroma.Config.put(
          [:instance, :account_activation_required],
          orig_account_activation_required
        )
      end)

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "test", email: ""})

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}
    end

    test "with proper permissions, valid password and non unique email", %{
      conn: conn
    } do
      user = insert(:user)

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "test", email: user.email})

      assert json_response_and_validate_schema(conn, 200) == %{
               "error" => "Email has already been taken."
             }
    end

    test "with proper permissions, valid password and valid email", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_email", %{password: "test", email: "cofe@foobar.com"})

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}
    end
  end

  describe "POST /api/pleroma/change_password" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_password", %{
          "password" => "hi",
          "new_password" => "newpass",
          "new_password_confirmation" => "newpass"
        })

      assert json_response_and_validate_schema(conn, 403) == %{
               "error" => "Insufficient permissions: write:accounts."
             }
    end

    test "with proper permissions and invalid password", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_password", %{
          "password" => "hi",
          "new_password" => "newpass",
          "new_password_confirmation" => "newpass"
        })

      assert json_response_and_validate_schema(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with proper permissions, valid password and new password and confirmation not matching",
         %{
           conn: conn
         } do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_password", %{
          "password" => "test",
          "new_password" => "newpass",
          "new_password_confirmation" => "notnewpass"
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "error" => "New password does not match confirmation."
             }
    end

    test "with proper permissions, valid password and invalid new password", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/change_password", %{
          password: "test",
          new_password: "",
          new_password_confirmation: ""
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "error" => "New password can't be blank."
             }
    end

    test "with proper permissions, valid password and matching new password and confirmation", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post(
          "/api/pleroma/change_password",
          %{
            password: "test",
            new_password: "newpass",
            new_password_confirmation: "newpass"
          }
        )

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}
      fetched_user = User.get_cached_by_id(user.id)
      assert Pleroma.Password.Pbkdf2.verify_pass("newpass", fetched_user.password_hash) == true
    end
  end

  describe "POST /api/pleroma/delete_account" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> post("/api/pleroma/delete_account")

      assert json_response_and_validate_schema(conn, 403) ==
               %{"error" => "Insufficient permissions: write:accounts."}
    end

    test "with proper permissions and wrong or missing password", %{conn: conn} do
      for params <- [%{"password" => "hi"}, %{}] do
        ret_conn =
          conn
          |> put_req_header("content-type", "application/json")
          |> post("/api/pleroma/delete_account", params)

        assert json_response_and_validate_schema(ret_conn, 200) == %{
                 "error" => "Invalid password."
               }
      end
    end

    test "with proper permissions and valid password (URL query)", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/delete_account?password=test")

      ObanHelpers.perform_all()
      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}

      user = User.get_by_id(user.id)
      refute user.is_active
      assert user.name == nil
      assert user.bio == ""
      assert user.password_hash == nil
    end

    test "with proper permissions and valid password (JSON body)", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/pleroma/delete_account", %{password: "test"})

      ObanHelpers.perform_all()
      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}

      user = User.get_by_id(user.id)
      refute user.is_active
      assert user.name == nil
      assert user.bio == ""
      assert user.password_hash == nil
    end
  end

  describe "POST /api/pleroma/move_account" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      target_user = insert(:user)
      target_nick = target_user |> User.full_nickname()

      conn =
        conn
        |> assign(:token, nil)
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "hi",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 403) == %{
               "error" => "Insufficient permissions: write:accounts."
             }
    end

    test "with proper permissions and invalid password", %{conn: conn} do
      target_user = insert(:user)
      target_nick = target_user |> User.full_nickname()

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "hi",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 200) == %{"error" => "Invalid password."}
    end

    test "with proper permissions, valid password and target account does not alias this",
         %{
           conn: conn
         } do
      target_user = insert(:user)
      target_nick = target_user |> User.full_nickname()

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "test",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "error" => "Target account must have the origin in `alsoKnownAs`"
             }
    end

    test "with proper permissions, valid password and target account does not exist",
         %{
           conn: conn
         } do
      target_nick = "not_found@mastodon.social"

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "test",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 404) == %{
               "error" => "Target account not found."
             }
    end

    test "with proper permissions, valid password, remote target account aliases this and local cache does not exist",
         %{} do
      user = insert(:user, ap_id: "https://lm.kazv.moe/users/testuser")
      %{user: _user, conn: conn} = oauth_access(["write:accounts"], user: user)

      target_nick = "mewmew@lm.kazv.moe"

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "test",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}
    end

    test "with proper permissions, valid password, remote target account aliases this and local cache does not alias this",
         %{} do
      user = insert(:user, ap_id: "https://lm.kazv.moe/users/testuser")
      %{user: _user, conn: conn} = oauth_access(["write:accounts"], user: user)

      target_user =
        insert(
          :user,
          ap_id: "https://lm.kazv.moe/users/mewmew",
          nickname: "mewmew@lm.kazv.moe",
          local: false
        )

      target_nick = target_user |> User.full_nickname()

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "test",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}
    end

    test "with proper permissions, valid password, remote target account does not alias this and local cache aliases this",
         %{
           user: user,
           conn: conn
         } do
      target_user =
        insert(
          :user,
          ap_id: "https://lm.kazv.moe/users/mewmew",
          nickname: "mewmew@lm.kazv.moe",
          local: false,
          also_known_as: [user.ap_id]
        )

      target_nick = target_user |> User.full_nickname()

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/pleroma/move_account", %{
          "password" => "test",
          "target_account" => target_nick
        })

      assert json_response_and_validate_schema(conn, 200) == %{
               "error" => "Target account must have the origin in `alsoKnownAs`"
             }
    end

    test "with proper permissions, valid password and target account aliases this", %{
      conn: conn,
      user: user
    } do
      target_user = insert(:user, also_known_as: [user.ap_id])
      target_nick = target_user |> User.full_nickname()
      follower = insert(:user)

      User.follow(follower, user)

      assert User.following?(follower, user)

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post(
          "/api/pleroma/move_account",
          %{
            password: "test",
            target_account: target_nick
          }
        )

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}

      params = %{
        "op" => "move_following",
        "origin_id" => user.id,
        "target_id" => target_user.id
      }

      assert_enqueued(worker: Pleroma.Workers.BackgroundWorker, args: params)

      Pleroma.Workers.BackgroundWorker.perform(%Oban.Job{args: params})

      refute User.following?(follower, user)
      assert User.following?(follower, target_user)
    end

    test "prefix nickname by @ should work", %{
      conn: conn,
      user: user
    } do
      target_user = insert(:user, also_known_as: [user.ap_id])
      target_nick = target_user |> User.full_nickname()
      follower = insert(:user)

      User.follow(follower, user)

      assert User.following?(follower, user)

      conn =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post(
          "/api/pleroma/move_account",
          %{
            password: "test",
            target_account: "@" <> target_nick
          }
        )

      assert json_response_and_validate_schema(conn, 200) == %{"status" => "success"}

      params = %{
        "op" => "move_following",
        "origin_id" => user.id,
        "target_id" => target_user.id
      }

      assert_enqueued(worker: Pleroma.Workers.BackgroundWorker, args: params)

      Pleroma.Workers.BackgroundWorker.perform(%Oban.Job{args: params})

      refute User.following?(follower, user)
      assert User.following?(follower, target_user)
    end
  end

  describe "GET /api/pleroma/aliases" do
    setup do: oauth_access(["read:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> get("/api/pleroma/aliases")

      assert json_response_and_validate_schema(conn, 403) == %{
               "error" => "Insufficient permissions: read:accounts."
             }
    end

    test "with permissions", %{
      conn: conn
    } do
      assert %{"aliases" => []} =
               conn
               |> get("/api/pleroma/aliases")
               |> json_response_and_validate_schema(200)
    end

    test "with permissions and aliases", %{} do
      user = insert(:user)
      user2 = insert(:user)

      assert {:ok, user} = user |> User.add_alias(user2)

      %{user: _user, conn: conn} = oauth_access(["read:accounts"], user: user)

      assert %{"aliases" => aliases} =
               conn
               |> get("/api/pleroma/aliases")
               |> json_response_and_validate_schema(200)

      assert aliases == [user2 |> User.full_nickname()]
    end
  end

  describe "PUT /api/pleroma/aliases" do
    setup do: oauth_access(["write:accounts"])

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/aliases", %{alias: "none"})

      assert json_response_and_validate_schema(conn, 403) == %{
               "error" => "Insufficient permissions: write:accounts."
             }
    end

    test "with permissions, no alias param", %{
      conn: conn
    } do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/aliases", %{})

      assert %{"error" => "Missing field: alias."} = json_response_and_validate_schema(conn, 400)
    end

    test "with permissions, with alias param", %{
      conn: conn
    } do
      user2 = insert(:user)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put("/api/pleroma/aliases", %{alias: user2 |> User.full_nickname()})

      assert json_response_and_validate_schema(conn, 200) == %{
               "status" => "success"
             }
    end
  end

  describe "DELETE /api/pleroma/aliases" do
    setup do
      alias_user = insert(:user)
      non_alias_user = insert(:user)
      user = insert(:user, also_known_as: [alias_user.ap_id])

      oauth_access(["write:accounts"], user: user)
      |> Map.put(:alias_user, alias_user)
      |> Map.put(:non_alias_user, non_alias_user)
    end

    test "without permissions", %{conn: conn} do
      conn =
        conn
        |> assign(:token, nil)
        |> put_req_header("content-type", "application/json")
        |> delete("/api/pleroma/aliases", %{alias: "none"})

      assert json_response_and_validate_schema(conn, 403) == %{
               "error" => "Insufficient permissions: write:accounts."
             }
    end

    test "with permissions, no alias param", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/pleroma/aliases", %{})

      assert %{"error" => "Missing field: alias."} = json_response_and_validate_schema(conn, 400)
    end

    test "with permissions, account does not have such alias", %{
      conn: conn,
      non_alias_user: non_alias_user
    } do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/pleroma/aliases", %{alias: non_alias_user |> User.full_nickname()})

      assert %{"error" => "Account has no such alias."} =
               json_response_and_validate_schema(conn, 404)
    end

    test "with permissions, account does have such alias", %{
      conn: conn,
      alias_user: alias_user
    } do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/pleroma/aliases", %{alias: alias_user |> User.full_nickname()})

      assert %{"status" => "success"} = json_response_and_validate_schema(conn, 200)
    end
  end
end
