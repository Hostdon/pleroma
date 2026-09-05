# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityDraftTest do
  alias Pleroma.Web.CommonAPI.ActivityDraft

  use Pleroma.DataCase

  import Pleroma.Factory

  setup do
    user = insert(:user, local: true)

    %{user: user}
  end

  defp test_dm_addressing(from, to) do
    {:ok, draft} =
      ActivityDraft.create(from, %{
        status: "@#{to.nickname} hi",
        visibility: "direct"
      })

    assert to.ap_id in draft.mentions
  end

  describe "addresses mentioned user" do
    test "when no dot in name", %{user: user} do
      addr = insert(:user, local: false, nickname: "nix@example.org")
      test_dm_addressing(user, addr)
    end

    test "when dot in name", %{user: user} do
      addr = insert(:user, local: false, nickname: "ly.nx@example.org")
      test_dm_addressing(user, addr)
    end
  end
end
