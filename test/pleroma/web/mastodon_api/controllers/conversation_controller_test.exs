# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationControllerTest do
  use Pleroma.Web.ConnCase, async: false

  alias Pleroma.Conversation.Participation
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup do: oauth_access(["read:statuses"])

  describe "returns a list of conversations" do
    setup(%{user: user_one, conn: conn}) do
      user_two = insert(:user)
      user_three = insert(:user)

      {:ok, user_two, user_one} = User.follow(user_two, user_one)

      {:ok, %{user: user_one, user_two: user_two, user_three: user_three, conn: conn}}
    end

    test "returns correct conversations", %{
      user: user_one,
      user_two: user_two,
      user_three: user_three,
      conn: conn
    } do
      assert Participation.unread_count(user_two) == 0
      {:ok, direct} = create_direct_message(user_one, [user_two, user_three])

      assert Participation.unread_count(user_two) == 1

      {:ok, _follower_only} =
        CommonAPI.post(user_one, %{
          status: "Hi @#{user_two.nickname}!",
          visibility: "private"
        })

      res_conn = get(conn, "/api/v1/conversations")

      assert response = json_response_and_validate_schema(res_conn, 200)

      assert [
               %{
                 "id" => res_id,
                 "accounts" => res_accounts,
                 "last_status" => res_last_status,
                 "unread" => unread
               }
             ] = response

      account_ids = Enum.map(res_accounts, & &1["id"])
      assert length(res_accounts) == 2
      assert user_one.id not in account_ids
      assert user_two.id in account_ids
      assert user_three.id in account_ids
      assert is_binary(res_id)
      assert unread == false
      assert res_last_status["id"] == direct.id
      assert res_last_status["account"]["id"] == user_one.id
      assert Participation.unread_count(user_one) == 0
    end

    test "includes the user if the user is the only participant", %{
      user: user_one,
      conn: conn
    } do
      {:ok, _direct} = create_direct_message(user_one, [])

      res_conn = get(conn, "/api/v1/conversations")

      assert response = json_response_and_validate_schema(res_conn, 200)

      assert [
               %{
                 "accounts" => [account]
               }
             ] = response

      assert user_one.id == account["id"]
    end

    test "observes limit params", %{
      user: user_one,
      user_two: user_two,
      user_three: user_three,
      conn: conn
    } do
      {:ok, _} = create_direct_message(user_one, [user_two, user_three])
      {:ok, _} = create_direct_message(user_two, [user_one, user_three])
      {:ok, _} = create_direct_message(user_three, [user_two, user_one])

      res_conn = get(conn, "/api/v1/conversations?limit=1")

      assert response = json_response_and_validate_schema(res_conn, 200)

      assert Enum.count(response) == 1

      res_conn = get(conn, "/api/v1/conversations?limit=2")

      assert response = json_response_and_validate_schema(res_conn, 200)

      assert Enum.count(response) == 2
    end
  end

  test "paginates correctly", %{user: user, conn: conn} do
    [p1, p2, p3, p4] = for _ <- 1..4, do: insert(:participation, %{user: user})

    # jumble "last active" order to 4, 1, 3, 2
    CommonAPI.post(user, %{status: "beep", in_reply_to_status_id: p3.last_bump})
    CommonAPI.post(user, %{status: "beep", in_reply_to_status_id: p1.last_bump})
    CommonAPI.post(user, %{status: "beep", in_reply_to_status_id: p4.last_bump})

    expect_h1 = [to_string(p4.id), to_string(p1.id)]
    expect_h2 = [to_string(p3.id), to_string(p2.id)]
    expect_full = expect_h1 ++ expect_h2

    # Everything at once
    res_full_conn = get(conn, "/api/v1/conversations?limit=5")
    res_full = json_response_and_validate_schema(res_full_conn, 200)

    assert expect_full == Enum.map(res_full, & &1["id"])

    # First half / initial fetch
    res_h1_conn = get(conn, "/api/v1/conversations?limit=2")
    res_h1_link = :proplists.get_value("link", res_h1_conn.resp_headers, :none)
    res_h1 = json_response_and_validate_schema(res_h1_conn, 200)

    assert expect_h1 == Enum.map(res_h1, & &1["id"])
    assert res_h1_link != :none

    h1_links = parse_link_header(res_h1_link)
    h1_link_prev = :proplists.get_value("prev", h1_links, nil)
    h1_link_next = :proplists.get_value("next", h1_links, nil)

    assert Enum.all?(h1_links, fn {_, v} -> String.contains?(v, "limit=2") end)
    assert h1_link_prev
    assert h1_link_next

    # Following the link header
    res_h2_conn = get(conn, h1_link_next)
    res_h2_link = :proplists.get_value("link", res_h2_conn.resp_headers, :none)
    res_h2 = json_response_and_validate_schema(res_h2_conn, 200)

    assert expect_h2 == Enum.map(res_h2, & &1["id"])
    assert res_h1_link != :none

    h2_links = parse_link_header(res_h2_link)
    h2_link_prev = :proplists.get_value("prev", h2_links, nil)
    h2_link_next = :proplists.get_value("next", h2_links, nil)

    # Page after empty
    res_beyond =
      get(conn, h2_link_next)
      |> json_response_and_validate_schema(200)

    assert [] == res_beyond

    # Going back from h2 is identical to h1
    res_h1_reprise =
      get(conn, h2_link_prev)
      |> json_response_and_validate_schema(200)

    assert expect_h1 == Enum.map(res_h1_reprise, & &1["id"])
  end

  test "can paginate over filtered-out sections larger than limit", %{user: user, conn: conn} do
    blocked = insert(:user)

    p1 = insert(:participation, %{user: user})

    CommonAPI.post(blocked, %{
      status: "@#{user.nickname} buy the best NFTs here!: xxx",
      visibility: "direct"
    })

    CommonAPI.post(blocked, %{
      status: "@#{user.nickname} invest in the AI future now: xxx",
      visibility: "direct"
    })

    p4 = insert(:participation, %{user: user})

    full_noblock =
      get(conn, "/api/v1/conversations?limit=20")
      |> json_response_and_validate_schema(200)

    assert length(full_noblock) == 4
    [%{"id" => p4_id}, _, _, %{"id" => p1_id}] = full_noblock
    assert p4_id == to_string(p4.id)
    assert p1_id == to_string(p1.id)

    CommonAPI.block(user, blocked)
    expect_full = [to_string(p4.id), to_string(p1.id)]

    full_block =
      get(conn, "/api/v1/conversations?limit=20")
      |> json_response_and_validate_schema(200)

    assert length(full_block) == 2
    assert expect_full == Enum.map(full_block, & &1["id"])

    # paginate such that there’l be a block of filtered participations exceeding limit
    full_paginated = paginate_to_end(conn, "/api/v1/conversations?limit=1", [])
    assert expect_full == Enum.map(full_paginated, & &1["id"])
  end

  test "filters conversations by recipients", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    user_three = insert(:user)
    {:ok, direct1} = create_direct_message(user_one, [user_two])
    {:ok, _direct2} = create_direct_message(user_one, [user_three])
    {:ok, direct3} = create_direct_message(user_one, [user_two, user_three])
    {:ok, _direct4} = create_direct_message(user_two, [user_three])
    {:ok, direct5} = create_direct_message(user_two, [user_one])

    assert [conversation1, conversation2] =
             conn
             |> get("/api/v1/conversations?recipients[]=#{user_two.id}")
             |> json_response_and_validate_schema(200)

    assert conversation1["last_status"]["id"] == direct5.id
    assert conversation2["last_status"]["id"] == direct1.id

    [conversation1] =
      conn
      |> get("/api/v1/conversations?recipients[]=#{user_two.id}&recipients[]=#{user_three.id}")
      |> json_response_and_validate_schema(200)

    assert conversation1["last_status"]["id"] == direct3.id
  end

  test "updates the last_status on reply", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    {:ok, direct} = create_direct_message(user_one, [user_two])

    {:ok, direct_reply} =
      CommonAPI.post(user_two, %{
        status: "reply",
        visibility: "direct",
        in_reply_to_status_id: direct.id
      })

    [%{"last_status" => res_last_status}] =
      conn
      |> get("/api/v1/conversations")
      |> json_response_and_validate_schema(200)

    assert res_last_status["id"] == direct_reply.id
  end

  test "the user marks a conversation as read", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    {:ok, direct} = create_direct_message(user_one, [user_two])

    assert Participation.unread_count(user_one) == 0
    assert Participation.unread_count(user_two) == 1

    user_two_conn =
      build_conn()
      |> assign(:user, user_two)
      |> assign(
        :token,
        insert(:oauth_token, user: user_two, scopes: ["read:statuses", "write:conversations"])
      )

    [%{"id" => direct_conversation_id, "unread" => true}] =
      user_two_conn
      |> get("/api/v1/conversations")
      |> json_response_and_validate_schema(200)

    %{"unread" => false} =
      user_two_conn
      |> post("/api/v1/conversations/#{direct_conversation_id}/read")
      |> json_response_and_validate_schema(200)

    assert Participation.unread_count(user_one) == 0
    assert Participation.unread_count(user_two) == 0

    # The conversation is marked as unread on reply
    {:ok, _} =
      CommonAPI.post(user_two, %{
        status: "reply",
        visibility: "direct",
        in_reply_to_status_id: direct.id
      })

    [%{"unread" => true}] =
      conn
      |> get("/api/v1/conversations")
      |> json_response_and_validate_schema(200)

    assert Participation.unread_count(user_one) == 1
    assert Participation.unread_count(user_two) == 0

    # A reply doesn't increment the user's unread_conversation_count if the conversation is unread
    {:ok, _} =
      CommonAPI.post(user_two, %{
        status: "reply",
        visibility: "direct",
        in_reply_to_status_id: direct.id
      })

    assert Participation.unread_count(user_one) == 1
    assert Participation.unread_count(user_two) == 0
  end

  test "(vanilla) Mastodon frontend behaviour", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    {:ok, direct} = create_direct_message(user_one, [user_two])

    res_conn = get(conn, "/api/v1/statuses/#{direct.id}/context")

    assert %{"ancestors" => [], "descendants" => []} ==
             json_response_and_validate_schema(res_conn, 200)
  end

  test "Removes a conversation", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    token = insert(:oauth_token, user: user_one, scopes: ["read:statuses", "write:conversations"])

    {:ok, _direct} = create_direct_message(user_one, [user_two])
    {:ok, _direct} = create_direct_message(user_one, [user_two])

    assert [%{"id" => conv1_id}, %{"id" => conv2_id}] =
             conn
             |> assign(:token, token)
             |> get("/api/v1/conversations")
             |> json_response_and_validate_schema(200)

    assert %{} =
             conn
             |> assign(:token, token)
             |> delete("/api/v1/conversations/#{conv1_id}")
             |> json_response_and_validate_schema(200)

    assert [%{"id" => ^conv2_id}] =
             conn
             |> assign(:token, token)
             |> get("/api/v1/conversations")
             |> json_response_and_validate_schema(200)
  end

  defp create_direct_message(sender, recips) do
    hellos =
      recips
      |> Enum.map(fn s -> "@#{s.nickname}" end)
      |> Enum.join(", ")

    CommonAPI.post(sender, %{
      status: "Hi #{hellos}!",
      visibility: "direct"
    })
  end

  defp parse_link_header(link_header_val) when is_binary(link_header_val) do
    link_header_val
    |> String.split(",")
    |> Enum.map(fn l ->
      [link, reldir] =
        l
        |> String.split(";", parts: 2)
        |> Enum.map(fn part ->
          part
          |> String.trim(" ")
          |> String.trim_leading("<")
          |> String.trim_trailing(">")
        end)

      <<"rel=", dir::binary>> = reldir
      dir = String.trim(dir, "\"")

      {dir, link}
    end)
  end

  defp paginate_to_end(conn, uri, acc) do
    res_conn = get(conn, uri)
    res = json_response_and_validate_schema(res_conn, 200)
    acc = acc ++ res

    link_val = :proplists.get_value("link", res_conn.resp_headers, :none)

    if link_val == :none do
      acc
    else
      links = parse_link_header(link_val)
      next_uri = :proplists.get_value("next", links, nil)
      assert next_uri
      paginate_to_end(conn, next_uri, acc)
    end
  end
end
