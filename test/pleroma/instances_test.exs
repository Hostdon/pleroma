# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.InstancesTest do
  alias Pleroma.Instances

  use Pleroma.DataCase

  setup_all do: clear_config([:instance, :federation_reachability_timeout_days], 1)

  describe "reachable?/1" do
    test "returns `true` for host / url with unknown reachability status" do
      assert Instances.reachable?("unknown.site")
      assert Instances.reachable?("http://unknown.site")
    end

    test "returns `false` for host / url marked unreachable for at least `reachability_datetime_threshold()`" do
      host = "consistently-unreachable.name"
      Instances.set_consistently_unreachable(host)

      refute Instances.reachable?(host)
      refute Instances.reachable?("http://#{host}/path")
    end

    test "returns `true` for host / url marked unreachable for less than `reachability_datetime_threshold()`" do
      url = "http://eventually-unreachable.name/path"

      Instances.set_unreachable(url)

      assert Instances.reachable?(url)
      assert Instances.reachable?(URI.parse(url).host)
    end

    test "returns true on non-binary input" do
      assert Instances.reachable?(nil)
      assert Instances.reachable?(1)
    end
  end

  describe "filter_reachable/1" do
    setup do
      host = "consistently-unreachable.name"
      url1 = "http://eventually-unreachable.com/path"
      url2 = "http://domain.com/path"

      Instances.set_consistently_unreachable(host)
      Instances.set_unreachable(url1)

      result = Instances.filter_reachable([host, url1, url2, nil])
      %{result: result, url1: url1, url2: url2}
    end

    test "returns a map with keys containing 'not marked consistently unreachable' elements of supplied list",
         %{result: result, url1: url1, url2: url2} do
      assert is_map(result)
      assert Enum.sort([url1, url2]) == result |> Map.keys() |> Enum.sort()
    end

    test "returns a map with `unreachable_since` values for keys",
         %{result: result, url1: url1, url2: url2} do
      assert is_map(result)
      assert %NaiveDateTime{} = result[url1]
      assert is_nil(result[url2])
    end

    test "returns an empty map for empty list or list containing no hosts / url" do
      assert %{} == Instances.filter_reachable([])
      assert %{} == Instances.filter_reachable([nil])
    end
  end

  describe "set_reachable/1" do
    test "sets unreachable url or host reachable" do
      host = "domain.com"
      Instances.set_consistently_unreachable(host)
      refute Instances.reachable?(host)

      Instances.set_reachable(host)
      assert Instances.reachable?(host)
    end

    test "keeps reachable url or host reachable" do
      url = "https://site.name?q="
      assert Instances.reachable?(url)

      Instances.set_reachable(url)
      assert Instances.reachable?(url)
    end

    test "returns error status on non-binary input" do
      assert {:error, _} = Instances.set_reachable(nil)
      assert {:error, _} = Instances.set_reachable(1)
    end
  end

  # Note: implementation-specific (e.g. Instance) details of set_unreachable/1
  # should be tested in implementation-specific tests
  describe "set_unreachable/1" do
    test "returns error status on non-binary input" do
      assert {:error, _} = Instances.set_unreachable(nil)
      assert {:error, _} = Instances.set_unreachable(1)
    end
  end

  describe "set_consistently_unreachable/1" do
    test "sets reachable url or host unreachable" do
      url = "http://domain.com?q="
      assert Instances.reachable?(url)

      Instances.set_consistently_unreachable(url)
      refute Instances.reachable?(url)
    end

    test "keeps unreachable url or host unreachable" do
      host = "site.name"
      Instances.set_consistently_unreachable(host)
      refute Instances.reachable?(host)

      Instances.set_consistently_unreachable(host)
      refute Instances.reachable?(host)
    end
  end
end
