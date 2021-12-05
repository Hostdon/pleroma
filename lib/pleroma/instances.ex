# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances do
  @moduledoc "Instances context."

  @adapter Pleroma.Instances.Instance

  defdelegate filter_reachable(urls_or_hosts), to: @adapter
  defdelegate reachable?(url_or_host), to: @adapter
  defdelegate set_reachable(url_or_host), to: @adapter
  defdelegate set_unreachable(url_or_host, unreachable_since \\ nil), to: @adapter
  defdelegate get_consistently_unreachable(), to: @adapter

  def set_consistently_unreachable(url_or_host),
    do: set_unreachable(url_or_host, reachability_datetime_threshold())

  def reachability_datetime_threshold do
    federation_reachability_timeout_days =
      Pleroma.Config.get([:instance, :federation_reachability_timeout_days], 0)

    if federation_reachability_timeout_days > 0 do
      NaiveDateTime.add(
        NaiveDateTime.utc_now(),
        -federation_reachability_timeout_days * 24 * 3600,
        :second
      )
    else
      ~N[0000-01-01 00:00:00]
    end
  end

  def host(url_or_host) when is_binary(url_or_host) do
    if url_or_host =~ ~r/^http/i do
      URI.parse(url_or_host).host
    else
      url_or_host
    end
  end
end
