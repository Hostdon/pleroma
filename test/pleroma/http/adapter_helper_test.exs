# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelperTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.HTTP.AdapterHelper

  defp get_proxy_val(opts) do
    opts
    |> Keyword.get(:pools)
    |> then(& &1[:default])
    |> Keyword.get(:conn_opts)
    |> Keyword.get(:proxy, :undefined)
  end

  defp assert_proxy_val(inp, ref) do
    clear_config([:http, :proxy_url], inp)
    opts = AdapterHelper.options()
    assert get_proxy_val(opts) == ref
  end

  describe "accepts proxy format" do
    test "with nil" do
      assert_proxy_val(nil, :undefined)
    end

    test "with string" do
      assert_proxy_val("http://127.0.0.1:8123", {:http, "127.0.0.1", 8123, []})
    end

    test "localhost with port" do
      assert_proxy_val("https://localhost:8123", {:https, "localhost", 8123, []})
    end

    test "tuple" do
      assert_proxy_val({:http, "localhost", 9050}, {:http, "localhost", 9050, []})
    end
  end

  test "properly merges default with passed runtime config" do
    clear_config([:http, :proxy_url], "http://127.0.0.1:8123")
    opts = AdapterHelper.options(pools: %{default: [conn_opts: [already: "set"]]})

    assert get_proxy_val(opts) == {:http, "127.0.0.1", 8123, []}

    assert "set" ==
             opts
             |> Keyword.get(:pools)
             |> then(& &1[:default])
             |> Keyword.get(:conn_opts)
             |> Keyword.get(:already)
  end
end
