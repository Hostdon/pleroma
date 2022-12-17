# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.ImportTest do
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "follow_import" do
    test "it imports user followings from list" do
      [user1, user2, user3] = insert_list(3, :user)

      identifiers = [
        user2.ap_id,
        user3.nickname
      ]

      [{:ok, job1}, {:ok, job2}] = User.Import.follow_import(user1, identifiers)

      assert {:ok, result} = ObanHelpers.perform(job1)
      assert result == refresh_record(user2)

      assert {:ok, result} = ObanHelpers.perform(job2)
      assert result == refresh_record(user3)

      assert User.following?(user1, user2)
      assert User.following?(user1, user3)
    end
  end

  describe "blocks_import" do
    test "it imports user blocks from list" do
      [user1, user2, user3] = insert_list(3, :user)

      identifiers = [
        user2.ap_id,
        user3.nickname
      ]

      [{:ok, job1}, {:ok, job2}] = User.Import.blocks_import(user1, identifiers)

      assert {:ok, result} = ObanHelpers.perform(job1)
      assert result == user2

      assert {:ok, result} = ObanHelpers.perform(job2)
      assert result == user3

      assert User.blocks?(user1, user2)
      assert User.blocks?(user1, user3)
    end
  end

  describe "mutes_import" do
    test "it imports user mutes from list" do
      [user1, user2, user3] = insert_list(3, :user)

      identifiers = [
        user2.ap_id,
        user3.nickname
      ]

      [{:ok, job1}, {:ok, job2}] = User.Import.mutes_import(user1, identifiers)

      assert {:ok, result} = ObanHelpers.perform(job1)
      assert result == user2

      assert {:ok, result} = ObanHelpers.perform(job2)
      assert result == user3

      assert User.mutes?(user1, user2)
      assert User.mutes?(user1, user3)
    end
  end
end
