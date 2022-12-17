# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  import Pleroma.Web.ActivityPub.MRF.HellthreadPolicy

  setup do
    user = insert(:user)

    message = %{
      "actor" => user.ap_id,
      "cc" => [user.follower_address],
      "type" => "Create",
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://instance.tld/users/user1",
        "https://instance.tld/users/user2",
        "https://instance.tld/users/user3"
      ],
      "object" => %{
        "type" => "Note"
      }
    }

    update_message = %{
      "actor" => user.ap_id,
      "cc" => [user.follower_address],
      "type" => "Update",
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://instance.tld/users/user1",
        "https://instance.tld/users/user2",
        "https://instance.tld/users/user3"
      ],
      "object" => %{
        "type" => "Note"
      }
    }

    [user: user, message: message, update_message: update_message]
  end

  setup do: clear_config(:mrf_hellthread)

  describe "reject" do
    test "rejects the message if the recipient count is above reject_threshold", %{
      message: message,
      update_message: update_message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 2})

      assert {:reject, "[HellthreadPolicy] 3 recipients is over the limit of 2"} ==
               filter(message)

      assert {:reject, "[HellthreadPolicy] 3 recipients is over the limit of 2"} ==
               filter(update_message)
    end

    test "does not reject the message if the recipient count is below reject_threshold", %{
      message: message,
      update_message: update_message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 3})

      assert {:ok, ^message} = filter(message)
      assert {:ok, ^update_message} = filter(update_message)
    end
  end

  describe "delist" do
    test "delists the message if the recipient count is above delist_threshold", %{
      user: user,
      message: message,
      update_message: update_message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 2, reject_threshold: 0})

      {:ok, message} = filter(message)
      assert user.follower_address in message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in message["cc"]

      {:ok, update_message} = filter(update_message)
      assert user.follower_address in update_message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in update_message["cc"]
    end

    test "does not delist the message if the recipient count is below delist_threshold", %{
      message: message,
      update_message: update_message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 4, reject_threshold: 0})

      assert {:ok, ^message} = filter(message)
      assert {:ok, ^update_message} = filter(update_message)
    end
  end

  test "excludes follower collection and public URI from threshold count", %{
    message: message,
    update_message: update_message
  } do
    clear_config([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 3})

    assert {:ok, ^message} = filter(message)
    assert {:ok, ^update_message} = filter(update_message)
  end
end
