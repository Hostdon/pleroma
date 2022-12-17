# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlugTest do
  use Pleroma.Web.ConnCase, async: false
  import Pleroma.Factory
  alias Pleroma.Web.Plugs.HTTPSignaturePlug
  alias Pleroma.Instances.Instance
  alias Pleroma.Repo

  import Plug.Conn
  import Phoenix.Controller, only: [put_format: 2]
  import Mock

  setup_with_mocks([
    {HTTPSignatures, [],
     [
       signature_for_conn: fn _ ->
         %{"keyId" => "http://mastodon.example.org/users/admin#main-key"}
       end,
       validate_conn: fn conn ->
         Map.get(conn.assigns, :valid_signature, true)
       end
     ]}
  ]) do
    :ok
  end

  defp submit_to_plug(host), do: submit_to_plug(host, :get, "/doesntmattter")

  defp submit_to_plug(host, method, path) do
    params = %{"actor" => "http://#{host}/users/admin"}

    build_conn(method, path, params)
    |> put_req_header(
      "signature",
      "keyId=\"http://#{host}/users/admin#main-key"
    )
    |> put_format("activity+json")
    |> HTTPSignaturePlug.call(%{})
  end

  test "it call HTTPSignatures to check validity if the actor signed it" do
    params = %{"actor" => "http://mastodon.example.org/users/admin"}
    conn = build_conn(:get, "/doesntmattter", params)

    conn =
      conn
      |> put_req_header(
        "signature",
        "keyId=\"http://mastodon.example.org/users/admin#main-key"
      )
      |> put_format("activity+json")
      |> HTTPSignaturePlug.call(%{})

    assert conn.assigns.valid_signature == true
    assert conn.assigns.signature_actor_id == params["actor"]
    assert conn.halted == false
    assert called(HTTPSignatures.validate_conn(:_))
  end

  test "it sets request signatures property on the instance" do
    host = "mastodon.example.org"
    conn = submit_to_plug(host)
    assert conn.assigns.valid_signature == true
    instance = Repo.get_by(Instance, %{host: host})
    assert instance.has_request_signatures
  end

  test "it does not set request signatures property on the instance when using inbox" do
    host = "mastodon.example.org"
    conn = submit_to_plug(host, :post, "/inbox")
    assert conn.assigns.valid_signature == true

    # we don't even create the instance entry if its just POST /inbox
    refute Repo.get_by(Instance, %{host: host})
  end

  test "it does not set request signatures property on the instance when its cached" do
    host = "mastodon.example.org"
    Cachex.put(:request_signatures_cache, host, true)
    conn = submit_to_plug(host)
    assert conn.assigns.valid_signature == true

    # we don't even create the instance entry if it was already done
    refute Repo.get_by(Instance, %{host: host})
  end

  describe "requires a signature when `authorized_fetch_mode` is enabled" do
    setup do
      clear_config([:activitypub, :authorized_fetch_mode], true)

      params = %{"actor" => "http://mastodon.example.org/users/admin"}
      conn = build_conn(:get, "/doesntmattter", params) |> put_format("activity+json")

      [conn: conn]
    end

    test "and signature is present and incorrect", %{conn: conn} do
      conn =
        conn
        |> assign(:valid_signature, false)
        |> put_req_header(
          "signature",
          "keyId=\"http://mastodon.example.org/users/admin#main-key"
        )
        |> HTTPSignaturePlug.call(%{})

      assert conn.assigns.valid_signature == false
      assert conn.halted == true
      assert conn.status == 401
      assert conn.state == :sent
      assert conn.resp_body == "Request not signed"
      assert called(HTTPSignatures.validate_conn(:_))
    end

    test "and signature is correct", %{conn: conn} do
      conn =
        conn
        |> put_req_header(
          "signature",
          "keyId=\"http://mastodon.example.org/users/admin#main-key"
        )
        |> HTTPSignaturePlug.call(%{})

      assert conn.assigns.valid_signature == true
      assert conn.halted == false
      assert called(HTTPSignatures.validate_conn(:_))
    end

    test "and halts the connection when `signature` header is not present", %{conn: conn} do
      conn = HTTPSignaturePlug.call(conn, %{})
      assert conn.assigns[:valid_signature] == nil
      assert conn.halted == true
      assert conn.status == 401
      assert conn.state == :sent
      assert conn.resp_body == "Request not signed"
    end
  end

  test "aliases redirected /object endpoints", _ do
    obj = insert(:note)
    act = insert(:note_activity, note: obj)
    params = %{"actor" => "someparam"}
    path = URI.parse(obj.data["id"]).path
    conn = build_conn(:get, path, params)

    assert ["/notice/#{act.id}", "/notice/#{act.id}?actor=someparam"] ==
             HTTPSignaturePlug.route_aliases(conn)
  end
end
