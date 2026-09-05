# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.MappedSignatureToIdentityPlugTest do
  use Pleroma.Web.ConnCase, async: false
  alias Pleroma.Web.Plugs.MappedSignatureToIdentityPlug

  import Tesla.Mock
  import Plug.Conn
  import Pleroma.Factory

  import Pleroma.Tests.Helpers, only: [clear_config: 2]

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)

    user =
      insert(:user)
      |> with_signing_key()

    {:ok, %{user: user}}
  end

  defp set_signature(conn, %Pleroma.User{} = user) do
    conn
    |> assign(:valid_signature, true)
    |> assign(:signature_user, user)
  end

  defp set_signature(conn, ap_id) when is_binary(ap_id) do
    {:ok, user} = Pleroma.User.get_or_fetch_by_ap_id(ap_id)
    set_signature(conn, user)
  end

  test "it successfully maps a valid identity with a valid signature", %{user: user} do
    conn =
      build_conn(:get, "/doesntmattter")
      |> set_signature(user)
      |> MappedSignatureToIdentityPlug.call(%{})

    refute is_nil(conn.assigns.user)
  end

  test "it successfully maps a valid identity with a valid signature with payload", %{user: user} do
    conn =
      build_conn(:post, "/doesntmattter", %{"actor" => user.ap_id})
      |> set_signature(user)
      |> MappedSignatureToIdentityPlug.call(%{})

    refute is_nil(conn.assigns.user)
  end

  test "it considers a mapped identity to be invalid when it mismatches a payload", %{user: user} do
    conn =
      build_conn(:post, "/doesntmattter", %{"actor" => user.ap_id})
      |> set_signature("https://niu.moe/users/rye")
      |> MappedSignatureToIdentityPlug.call(%{})

    assert conn.assigns.valid_signature == false
    refute is_nil(conn.assigns.signature_user)
    refute match?(%{user: _}, conn.assigns)
  end

  test "it considers a mapped identity to be invalid when the associated instance is blocked", %{
    user: user
  } do
    clear_config([:activitypub, :authorized_fetch_mode], true)

    # extract domain from user.ap_id
    url = URI.parse(user.ap_id)

    clear_config([:mrf_simple, :reject], [
      {url.host, "anime is banned"}
    ])

    on_exit(fn ->
      Pleroma.Config.put([:activitypub, :authorized_fetch_mode], false)
      Pleroma.Config.put([:mrf_simple, :reject], [])
    end)

    conn =
      build_conn(:post, "/doesntmattter", %{"actor" => user.ap_id})
      |> set_signature(user)
      |> MappedSignatureToIdentityPlug.call(%{})

    assert conn.assigns.valid_signature == false
    refute is_nil(conn.assigns.signature_user)
    refute match?(%{user: _}, conn.assigns)
  end

  test "allowlist federation: it considers a mapped identity to be valid when the associated instance is allowed",
       %{user: user} do
    clear_config([:activitypub, :authorized_fetch_mode], true)

    url = URI.parse(user.ap_id)

    clear_config([:mrf_simple, :accept], [
      {url.host, "anime is allowed"}
    ])

    on_exit(fn ->
      Pleroma.Config.put([:activitypub, :authorized_fetch_mode], false)
      Pleroma.Config.put([:mrf_simple, :accept], [])
    end)

    conn =
      build_conn(:post, "/doesntmattter", %{"actor" => user.ap_id})
      |> set_signature(user)
      |> MappedSignatureToIdentityPlug.call(%{})

    assert conn.assigns[:valid_signature]
    refute is_nil(conn.assigns.user)
  end

  test "allowlist federation: it considers a mapped identity to be invalid when the associated instance is not allowed",
       %{user: user} do
    clear_config([:activitypub, :authorized_fetch_mode], true)

    clear_config([:mrf_simple, :accept], [
      {"misskey.example.org", "anime is allowed"}
    ])

    on_exit(fn ->
      Pleroma.Config.put([:activitypub, :authorized_fetch_mode], false)
      Pleroma.Config.put([:mrf_simple, :accept], [])
    end)

    conn =
      build_conn(:post, "/doesntmattter", %{"actor" => user.ap_id})
      |> set_signature(user)
      |> MappedSignatureToIdentityPlug.call(%{})

    assert conn.assigns.valid_signature == false
    refute is_nil(conn.assigns.signature_user)
    refute match?(%{user: _}, conn.assigns)
  end
end
