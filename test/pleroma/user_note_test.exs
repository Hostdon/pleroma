# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UserNoteTest do
  alias Pleroma.UserNote

  use Pleroma.DataCase, async: false
  import Pleroma.Factory

  describe "show/2" do
    setup do
      {:ok, users: insert_list(2, :user)}
    end

    test "if record does not exist, returns empty string", %{users: [user1, user2]} do
      comment = UserNote.show(user1, user2)

      assert comment == ""
    end

    test "if record exists with comment == nil, returns empty string", %{users: [user1, user2]} do
      UserNote.create(user1, user2, nil)

      comment = UserNote.show(user1, user2)

      assert comment == ""
    end

    test "if record exists with non-nil comment, returns comment", %{users: [user1, user2]} do
      expected_comment = "hello"
      UserNote.create(user1, user2, expected_comment)

      comment = UserNote.show(user1, user2)

      assert comment == expected_comment
    end
  end
end
