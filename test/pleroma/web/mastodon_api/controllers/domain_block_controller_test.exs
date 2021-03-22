# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.DomainBlockControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User

  import Pleroma.Factory

  test "blocking / unblocking a domain" do
    %{user: user, conn: conn} = oauth_access(["write:blocks"])
    other_user = insert(:user, %{ap_id: "https://dogwhistle.zone/@pundit"})

    ret_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/domain_blocks", %{"domain" => "dogwhistle.zone"})

    assert %{} == json_response_and_validate_schema(ret_conn, 200)
    user = User.get_cached_by_ap_id(user.ap_id)
    assert User.blocks?(user, other_user)

    ret_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/domain_blocks", %{"domain" => "dogwhistle.zone"})

    assert %{} == json_response_and_validate_schema(ret_conn, 200)
    user = User.get_cached_by_ap_id(user.ap_id)
    refute User.blocks?(user, other_user)
  end

  test "blocking a domain via query params" do
    %{user: user, conn: conn} = oauth_access(["write:blocks"])
    other_user = insert(:user, %{ap_id: "https://dogwhistle.zone/@pundit"})

    ret_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/domain_blocks?domain=dogwhistle.zone")

    assert %{} == json_response_and_validate_schema(ret_conn, 200)
    user = User.get_cached_by_ap_id(user.ap_id)
    assert User.blocks?(user, other_user)
  end

  test "unblocking a domain via query params" do
    %{user: user, conn: conn} = oauth_access(["write:blocks"])
    other_user = insert(:user, %{ap_id: "https://dogwhistle.zone/@pundit"})

    User.block_domain(user, "dogwhistle.zone")
    user = refresh_record(user)
    assert User.blocks?(user, other_user)

    ret_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/v1/domain_blocks?domain=dogwhistle.zone")

    assert %{} == json_response_and_validate_schema(ret_conn, 200)
    user = User.get_cached_by_ap_id(user.ap_id)
    refute User.blocks?(user, other_user)
  end

  test "getting a list of domain blocks" do
    %{user: user, conn: conn} = oauth_access(["read:blocks"])

    {:ok, user} = User.block_domain(user, "bad.site")
    {:ok, user} = User.block_domain(user, "even.worse.site")

    assert ["even.worse.site", "bad.site"] ==
             conn
             |> assign(:user, user)
             |> get("/api/v1/domain_blocks")
             |> json_response_and_validate_schema(200)
  end
end
