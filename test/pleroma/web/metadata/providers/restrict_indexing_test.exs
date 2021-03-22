# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.RestrictIndexingTest do
  use ExUnit.Case, async: true

  describe "build_tags/1" do
    test "for remote user" do
      assert Pleroma.Web.Metadata.Providers.RestrictIndexing.build_tags(%{
               user: %Pleroma.User{local: false}
             }) == [{:meta, [name: "robots", content: "noindex, noarchive"], []}]
    end

    test "for local user" do
      assert Pleroma.Web.Metadata.Providers.RestrictIndexing.build_tags(%{
               user: %Pleroma.User{local: true, discoverable: true}
             }) == []
    end

    test "for local user when discoverable is false" do
      assert Pleroma.Web.Metadata.Providers.RestrictIndexing.build_tags(%{
               user: %Pleroma.User{local: true, discoverable: false}
             }) == [{:meta, [name: "robots", content: "noindex, noarchive"], []}]
    end
  end
end
