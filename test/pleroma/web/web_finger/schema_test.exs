# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFingerTest do
  use Pleroma.DataCase
  alias Pleroma.Web.WebFinger.Schema
  alias Pleroma.Web.XML
  import Pleroma.Factory
  import Tesla.Mock

  @apt_canonical "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
  @apt_mastodon "application/activity+json"

  setup do
    mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  describe "host meta" do
    test "returns a link to the xml lrdd" do
      host_info = Schema.host_meta()

      assert String.contains?(host_info, Pleroma.Web.Endpoint.url())
    end
  end

  describe "incoming webfinger request" do
    test "works for fqns" do
      user = insert(:user)

      {:ok, result} =
        Schema.webfinger("#{user.nickname}@#{Pleroma.Web.Endpoint.host()}", "XML")

      assert is_binary(result)
    end

    test "works for ap_ids" do
      user = insert(:user)

      {:ok, result} = Schema.webfinger(user.ap_id, "XML")
      assert is_binary(result)
    end

    test "fails for remote ap_ids" do
      user = insert(:user, local: false)

      {:error, _} = Schema.webfinger(user.ap_id, "XML")
      {:error, _} = Schema.webfinger(user.ap_id, "JSON")
    end

    test "exposes AP id with both canonical and Mastodon content type in JSON" do
      user = insert(:user, local: true)
      {:ok, data} = Schema.webfinger(user.ap_id, "JSON")

      assert is_list(data["links"])

      canonical = Enum.find(data["links"], &(&1["type"] == @apt_canonical))
      mastodon = Enum.find(data["links"], &(&1["type"] == @apt_mastodon))

      assert canonical
      assert canonical["href"] == user.ap_id

      assert mastodon
      assert mastodon["href"] == user.ap_id
    end

    test "exposes AP id with both canonical and Mastodon content type in XML" do
      user = insert(:user, local: true)
      {:ok, binary_data} = Schema.webfinger(user.ap_id, "XML")

      {:ok, data} = XML.parse_document(binary_data)
      path = &(~s{//Link[@rel="self" and @type='} <> &1 <> ~s{']/@href})

      canonical = XML.string_from_xpath(path.(@apt_canonical), data)
      mastodon = XML.string_from_xpath(path.(@apt_mastodon), data)

      assert canonical == user.ap_id
      assert mastodon == user.ap_id
    end
  end
end
