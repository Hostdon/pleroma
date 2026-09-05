# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.AdapterHelper do
  @moduledoc """
  Configure Tesla.Client with default and customized adapter options.
  """

  @type proxy_type() :: :socks4 | :socks5
  @type host() :: charlist() | :inet.ip_address()

  alias Pleroma.Config
  require Logger

  @type proxy :: {Connection.proxy_type(), Connection.host(), pos_integer(), list()}

  @doc """
  Merge default connection & adapter options with received ones.
  """
  @spec options(Keyword.t()) :: Keyword.t()
  def options(opts \\ []) do
    [
      name: MyFinch,
      pools: %{
        default: [
          size: Config.get!([:http, :pool_size]),
          pool_max_idle_time: Config.get!([:http, :pool_timeout]),
          conn_max_idle_time: Config.get!([:http, :receive_timeout]),
          protocols: Config.get!([:http, :protocols]),
          conn_opts: [
            transport_opts: [
              inet6: true,
              inet4: true,
              cacerts: :public_key.cacerts_get()
            ]
          ]
        ]
      }
    ]
    |> maybe_add_proxy_pool(Config.get([:http, :proxy_url]))
    |> nested_merge(opts)
    # Ensure name is not overwritten
    |> Keyword.put(:name, MyFinch)
  end

  @spec nested_merge(Keyword.t(), Keyword.t()) :: Keyword.t()
  defp nested_merge(k1, k2) do
    Keyword.merge(k1, k2, &nested_merge/3)
  end

  defp nested_merge(_key, v1, v2) when is_list(v1) and is_list(v2) do
    if Keyword.keyword?(v1) and Keyword.keyword?(v2) do
      nested_merge(v1, v2)
    else
      v2
    end
  end

  defp nested_merge(_key, v1, v2) when is_map(v1) and is_map(v2) do
    Map.merge(v1, v2, &nested_merge/3)
  end

  defp nested_merge(_key, _v1, v2), do: v2

  defp maybe_add_proxy_pool(opts, proxy_config) do
    case format_proxy(proxy_config) do
      nil ->
        opts

      proxy ->
        Logger.info("Using HTTP Proxy: #{inspect(proxy)}")
        put_in(opts, [:pools, :default, :conn_opts, :proxy], proxy)
    end
  end

  @spec format_proxy(String.t() | tuple() | nil) :: proxy() | nil
  defp format_proxy(proxy_url) do
    case parse_proxy(proxy_url) do
      {:ok, type, host, port} -> {type, host, port, []}
      _ -> nil
    end
  end

  defp proxy_type("http"), do: {:ok, :http}
  defp proxy_type("https"), do: {:ok, :https}
  defp proxy_type(_), do: {:error, :unknown}

  @spec parse_proxy(String.t() | tuple() | nil) ::
          {:ok, proxy_type(), host(), pos_integer()}
          | {:error, atom()}
          | nil
  defp parse_proxy(nil), do: nil
  defp parse_proxy(""), do: nil

  defp parse_proxy(proxy) when is_binary(proxy) do
    with %URI{} = uri <- URI.parse(proxy),
         {:ok, type} <- proxy_type(uri.scheme) do
      {:ok, type, uri.host, uri.port}
    else
      e ->
        Logger.warning("Parsing proxy failed #{inspect(proxy)}, #{inspect(e)}")
        {:error, :invalid_proxy}
    end
  end

  defp parse_proxy(proxy) when is_tuple(proxy) do
    with {type, host, port} <- proxy do
      {:ok, type, host, port}
    else
      _ ->
        Logger.warning("Parsing proxy failed #{inspect(proxy)}")
        {:error, :invalid_proxy}
    end
  end
end
