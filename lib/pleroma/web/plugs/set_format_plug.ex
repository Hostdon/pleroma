# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.SetFormatPlug do
  import Plug.Conn, only: [assign: 3, fetch_query_params: 1]

  def init(_), do: nil

  def call(conn, _) do
    case get_format(conn) do
      nil -> conn
      format -> assign(conn, :format, format)
    end
  end

  defp get_format(conn) do
    conn.private[:phoenix_format] ||
      case fetch_query_params(conn) do
        %{query_params: %{"_format" => format}} -> format
        _ -> nil
      end
  end
end
