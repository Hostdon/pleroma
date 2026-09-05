# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.StatsTest do
  use Pleroma.DataCase, async: true

  import Pleroma.Factory

  alias Pleroma.Stats

  describe "user count" do
    test "it ignores internal users" do
      _user = insert(:user, local: true)
      _internal = insert(:user, local: true, nickname: nil)
      _internal = Pleroma.Web.ActivityPub.Relay.get_actor()

      assert match?(%{stats: %{user_count: 1}}, Stats.calculate_stat_data())
    end
  end
end
