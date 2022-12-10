# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper.Default do
  alias Pleroma.HTTP.AdapterHelper

  @behaviour Pleroma.HTTP.AdapterHelper

  @spec options(keyword(), URI.t()) :: keyword()
  def options(opts, _uri) do
    proxy = Pleroma.Config.get([:http, :proxy_url])
    pool_timeout = Pleroma.Config.get([:http, :pool_timeout], 5000)
    receive_timeout = Pleroma.Config.get([:http, :receive_timeout], 15_000)

    opts
    |> AdapterHelper.maybe_add_proxy(AdapterHelper.format_proxy(proxy))
    |> Keyword.put(:pool_timeout, pool_timeout)
    |> Keyword.put(:receive_timeout, receive_timeout)
  end

  @spec get_conn(URI.t(), keyword()) :: {:ok, keyword()}
  def get_conn(_uri, opts), do: {:ok, opts}
end
