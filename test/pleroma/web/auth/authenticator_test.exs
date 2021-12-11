# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Auth.AuthenticatorTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.Auth.Helpers
  import Pleroma.Factory

  describe "fetch_user/1" do
    test "returns user by name" do
      user = insert(:user)
      assert Helpers.fetch_user(user.nickname) == user
    end

    test "returns user by email" do
      user = insert(:user)
      assert Helpers.fetch_user(user.email) == user
    end

    test "returns nil" do
      assert Helpers.fetch_user("email") == nil
    end
  end

  describe "fetch_credentials/1" do
    test "returns name and password from authorization params" do
      params = %{"authorization" => %{"name" => "test", "password" => "test-pass"}}
      assert Helpers.fetch_credentials(params) == {:ok, {"test", "test-pass"}}
    end

    test "returns name and password with grant_type 'password'" do
      params = %{"grant_type" => "password", "username" => "test", "password" => "test-pass"}
      assert Helpers.fetch_credentials(params) == {:ok, {"test", "test-pass"}}
    end

    test "returns error" do
      assert Helpers.fetch_credentials(%{}) == {:error, :invalid_credentials}
    end
  end
end
