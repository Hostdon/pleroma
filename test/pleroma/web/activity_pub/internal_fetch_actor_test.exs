# Akkoma: Magically expressive social media
# Copyright © 2025 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.InternalFetchActorTests do
  use Pleroma.DataCase, async: true

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.InternalFetchActor

  test "creates a fetch actor if needed" do
    user = InternalFetchActor.get_actor()
    assert user
    assert user.ap_id == "#{Pleroma.Web.Endpoint.url()}/internal/fetch"
  end

  test "fetch actor is an application" do
    user = InternalFetchActor.get_actor()
    assert user.actor_type == "Application"
  end

  test "fetch actor doesn't expose follow* collections" do
    user = InternalFetchActor.get_actor()
    refute user.follower_address
    refute user.following_address
  end

  test "fetch actor is invisible" do
    user = InternalFetchActor.get_actor()
    assert User.invisible?(user)
  end
end
