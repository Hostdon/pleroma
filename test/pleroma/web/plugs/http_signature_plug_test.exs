# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlugTest do
  use Pleroma.Web.ConnCase, async: false
  @moduletag :mocked
  import Pleroma.Factory
  alias Pleroma.Web.Plugs.HTTPSignaturePlug

  import Plug.Conn
  import Phoenix.Controller, only: [put_format: 2]
  import Mock

  @user_ap_id "http://mastodon.example.org/users/admin"

  setup do
    user =
      :user
      |> insert(%{ap_id: "http://mastodon.example.org/users/admin"})
      |> with_signing_key(%{key_id: "http://mastodon.example.org/users/admin#main-key"})

    {:ok, %{user: user}}
  end

  setup_with_mocks([
    {HTTPSignatures, [],
     [
       validate_conn: fn conn, _ ->
         cond do
           Map.get(conn.assigns, :gone_signature_key, false) ->
             {:error, :gone}

           Map.get(conn.assigns, :rejected_key_id, false) ->
             {:error, {:reject, :mrf}}

           Map.get(conn.assigns, :valid_signature, true) ->
             {:ok, user} = Pleroma.User.get_or_fetch_by_ap_id(@user_ap_id)
             {:ok, %HTTPSignatures.HTTPKey{key: "aaa", user_data: %{"key_user" => user}}}

           true ->
             {:error, :wrong_signature}
         end
       end
     ]}
  ]) do
    :ok
  end

  test "it call HTTPSignatures to check validity if the actor signed it", %{user: user} do
    params = %{"actor" => user.ap_id}
    conn = build_conn(:get, "/doesntmattter", params)

    conn =
      conn
      |> assign(:host_matches, true)
      |> put_req_header(
        "signature",
        "keyId=\"#{user.signing_key.key_id}\""
      )
      |> put_format("activity+json")
      |> HTTPSignaturePlug.call(%{})

    assert conn.assigns.valid_signature == true
    assert conn.assigns.signature_user.ap_id == params["actor"]
    assert conn.halted == false
    assert called(HTTPSignatures.validate_conn(:_, :_))
  end

  describe "requires a signature when `authorized_fetch_mode` is enabled" do
    setup do
      clear_config([:activitypub, :authorized_fetch_mode], true)

      params = %{"actor" => "http://mastodon.example.org/users/admin"}

      conn =
        build_conn(:get, "/doesntmattter", params)
        |> put_format("activity+json")
        |> assign(:host_matches, true)

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
      assert called(HTTPSignatures.validate_conn(:_, :_))
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
      assert called(HTTPSignatures.validate_conn(:_, :_))
    end

    test "and halts the connection when `signature` header is not present", %{conn: conn} do
      conn = HTTPSignaturePlug.call(conn, %{})
      assert conn.assigns[:valid_signature] == nil
    end
  end

  test "aliases redirected /object endpoints", _ do
    obj = insert(:note)
    act = insert(:note_activity, note: obj)
    params = %{"actor" => "someparam"}
    path = URI.parse(obj.data["id"]).path
    conn = build_conn(:get, path, params)

    aliases =
      HTTPSignaturePlug.route_aliases(conn)
      |> Enum.reduce([], fn
        x, acc when is_binary(x) ->
          acc ++ [x]

        f, acc when is_function(f) ->
          add =
            case f.() do
              a when is_binary(a) -> [a]
              a -> a
            end

          acc ++ add
      end)

    assert ["get /notice/#{act.id}?actor=someparam", "get /notice/#{act.id}"] == aliases
  end

  test "fakes success on gone key when receiving Delete" do
    build_conn(:post, "/inbox", %{"type" => "Delete"})
    |> put_format("activity+json")
    |> assign(:host_matches, true)
    |> assign(:gone_signature_key, true)
    |> put_req_header(
      "signature",
      "keyId=\"http://somewhere.example.org/users/deleted#main-key\""
    )
    |> HTTPSignaturePlug.call(%{})
    |> response(202)
  end

  test "fails on gone key for non-Delete" do
    conn =
      build_conn(:post, "/inbox", %{"type" => "Note"})
      |> assign(:host_matches, true)
      |> put_format("activity+json")
      |> assign(:gone_signature_key, true)
      |> put_req_header(
        "signature",
        "keyId=\"http://somewhere.example.org/users/deleted#main-key\""
      )
      |> HTTPSignaturePlug.call(%{})

    refute conn.halted
    assert conn.assigns.valid_signature == false
    assert conn.assigns.signature_user == nil
  end

  test "fakes accept for POST on rejected keys", %{user: user} do
    build_conn(:post, "/inbox", %{"type" => "Note"})
    |> assign(:host_matches, true)
    |> put_format("activity+json")
    |> assign(:rejected_key_id, true)
    |> put_req_header(
      "signature",
      "keyId=\"#{user.signing_key.key_id}\""
    )
    |> HTTPSignaturePlug.call(%{})
    |> response(202)
  end

  test "fakes not found for GET on rejected keys", %{user: user} do
    build_conn(:get, "/doesntmattter", %{"user" => user.ap_id})
    |> assign(:host_matches, true)
    |> put_format("activity+json")
    |> assign(:rejected_key_id, true)
    |> put_req_header(
      "signature",
      "keyId=\"#{user.signing_key.key_id}\""
    )
    |> HTTPSignaturePlug.call(%{})
    |> response(404)
  end

  test "does not assign anything when a host match has not been run", %{user: user} do
    conn =
      build_conn(:get, "/doesntmattter", %{"user" => user.ap_id})
      |> assign(:host_matches, false)
      |> put_format("activity+json")
      |> put_req_header(
        "signature",
        "keyId=\"#{user.signing_key.key_id}\""
      )
      |> HTTPSignaturePlug.call(%{})

    refute Map.has_key?(conn.assigns, :valid_signature)
    refute Map.has_key?(conn.assigns, :signature_user)
  end
end
