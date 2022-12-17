# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelperTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.HTTP.AdapterHelper

  describe "format_proxy/1" do
    test "with nil" do
      assert AdapterHelper.format_proxy(nil) == nil
    end

    test "with string" do
      assert AdapterHelper.format_proxy("http://127.0.0.1:8123") == {:http, "127.0.0.1", 8123, []}
    end

    test "localhost with port" do
      assert AdapterHelper.format_proxy("https://localhost:8123") ==
               {:https, "localhost", 8123, []}
    end

    test "tuple" do
      assert AdapterHelper.format_proxy({:http, "localhost", 9050}) ==
               {:http, "localhost", 9050, []}
    end
  end

  describe "maybe_add_proxy_pool/1" do
    test "should do nothing with nil" do
      assert AdapterHelper.maybe_add_proxy_pool([], nil) == []
    end

    test "should create pools" do
      assert AdapterHelper.maybe_add_proxy_pool([], "proxy") == [
               pools: %{default: [conn_opts: [proxy: "proxy"]]}
             ]
    end

    test "should not override conn_opts if set" do
      assert AdapterHelper.maybe_add_proxy_pool(
               [pools: %{default: [conn_opts: [already: "set"]]}],
               "proxy"
             ) == [
               pools: %{default: [conn_opts: [proxy: "proxy", already: "set"]]}
             ]
    end
  end

  describe "timeout settings" do
    test "should default to 5000/15000" do
      options = AdapterHelper.options(%URI{host: 'somewhere'})
      assert options[:pool_timeout] == 5000
      assert options[:receive_timeout] == 15_000
    end

    test "pool_timeout should be overridden by :http, :pool_timeout" do
      clear_config([:http, :pool_timeout], 10_000)
      options = AdapterHelper.options(%URI{host: 'somewhere'})
      assert options[:pool_timeout] == 10_000
    end

    test "receive_timeout should be overridden by :http, :receive_timeout" do
      clear_config([:http, :receive_timeout], 20_000)
      options = AdapterHelper.options(%URI{host: 'somewhere'})
      assert options[:receive_timeout] == 20_000
    end
  end
end
