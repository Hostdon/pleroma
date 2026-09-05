# Akkoma: Magically expressive social media
# Copyright © 2022-2026 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsureHostPlug do
  @moduledoc """
  Ensures the request has a Host header, and that it matches this server
  """
  import Plug.Conn

  alias Pleroma.Web.Endpoint
  import Phoenix.Controller, only: [text: 2]

  def init(options) do
    options
  end

  def call(conn, _) do
    case get_req_header(conn, "host") do
      [host] ->
        handle_host_header(host, conn)

      [_host | _more] ->
        conn
        |> put_status(:bad_request)
        |> text("Bad host header")
        |> halt()

      [] ->
        handle_host_header(nil, conn)
    end
  end

  defp handle_host_header(value, conn) when is_binary(value) do
    our_uri = Endpoint.struct_url()
    default_port = URI.default_port(our_uri.scheme)
    expected_host = "#{our_uri.host}:#{our_uri.port}"

    if case_insensitive_matches?(value, expected_host) ||
         case_insensitive_matches?("#{value}:#{default_port}", expected_host) do
      assign(conn, :host_matches, true)
    else
      conn
      |> put_status(:bad_request)
      |> text("Host header does not match")
      |> halt()
    end
  end

  defp handle_host_header(_, conn) do
    conn
    |> put_status(:bad_request)
    |> text("Host header not present")
    |> halt()
  end

  defp case_insensitive_matches?(a, b) do
    String.downcase(a) == String.downcase(b)
  end
end
