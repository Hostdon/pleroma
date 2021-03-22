# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeMessageTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.User.WelcomeMessage

  import Pleroma.Factory

  setup do: clear_config([:welcome])

  describe "post_message/1" do
    test "send a direct welcome message" do
      welcome_user = insert(:user)
      user = insert(:user, name: "Jimm")

      Config.put([:welcome, :direct_message, :enabled], true)
      Config.put([:welcome, :direct_message, :sender_nickname], welcome_user.nickname)

      Config.put(
        [:welcome, :direct_message, :message],
        "Hello. Welcome to Pleroma"
      )

      {:ok, %Pleroma.Activity{} = activity} = WelcomeMessage.post_message(user)
      assert user.ap_id in activity.recipients
      assert activity.data["directMessage"] == true
      assert Pleroma.Object.normalize(activity).data["content"] =~ "Hello. Welcome to Pleroma"
    end
  end
end
