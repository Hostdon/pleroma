# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.ApUrlTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Providers.ApUrl

  @ap_type_compliant "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
  @ap_type_mastodon "application/activity+json"

  test "it preferentially renders a link to a post" do
    user = insert(:user)
    note = insert(:note, user: user)

    assert ApUrl.build_tags(%{object: note, user: user}) == [
             {:link, [rel: "alternate", href: note.data["id"], type: @ap_type_mastodon], []},
             {:link, [rel: "alternate", href: note.data["id"], type: @ap_type_compliant], []}
           ]
  end

  test "it renders a link to a user" do
    user = insert(:user)

    assert ApUrl.build_tags(%{user: user}) == [
             {:link, [rel: "alternate", href: user.ap_id, type: @ap_type_mastodon], []},
             {:link, [rel: "alternate", href: user.ap_id, type: @ap_type_compliant], []}
           ]
  end
end
