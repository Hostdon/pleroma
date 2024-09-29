# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.FrontendStatic do
  require Pleroma.Constants

  @frontend_cookie_name "preferred_frontend"

  @moduledoc """
  This is a shim to call `Plug.Static` but with runtime `from` configuration`. It dispatches to the different frontends.
  """
  @behaviour Plug

  defp instance_static_path do
    Pleroma.Config.get([:instance, :static_dir], "instance/static")
  end

  def file_path(path, frontend_type \\ :primary)

  def file_path(path, frontend_type) when is_atom(frontend_type) do
    if configuration = Pleroma.Config.get([:frontends, frontend_type]) do
      Path.join([
        instance_static_path(),
        "frontends",
        configuration["name"],
        configuration["ref"],
        path
      ])
    else
      nil
    end
  end

  def file_path(path, frontend_type) when is_binary(frontend_type) do
    Path.join([
      instance_static_path(),
      "frontends",
      frontend_type,
      path
    ])
  end

  def init(opts) do
    opts
    |> Keyword.put(:from, "__unconfigured_frontend_static_plug")
    |> Plug.Static.init()
    |> Map.put(:frontend_type, opts[:frontend_type])
    |> Map.put(:if, Keyword.get(opts, :if, true))
  end

  def call(conn, opts) do
    with false <- api_route?(conn.path_info),
         false <- invalid_path?(conn.path_info),
         true <- enabled?(opts[:if]),
         fallback_frontend_type <- Map.get(opts, :frontend_type, :primary),
         frontend_type <- preferred_or_fallback(conn, fallback_frontend_type),
         path when not is_nil(path) <- file_path("", frontend_type) do
      call_static(conn, opts, path)
    else
      _ ->
        conn
    end
  end

  def preferred_frontend(conn) do
    %{req_cookies: cookies} =
      conn
      |> Plug.Conn.fetch_cookies()

    Map.get(cookies, @frontend_cookie_name)
  end

  # Only override primary frontend
  def preferred_or_fallback(conn, :primary) do
    case preferred_frontend(conn) do
      nil ->
        :primary

      frontend ->
        if Enum.member?(Pleroma.Config.get([:frontends, :pickable], []), frontend) do
          frontend
        else
          :primary
        end
    end
  end

  def preferred_or_fallback(_conn, fallback), do: fallback

  defp enabled?(if_opt) when is_function(if_opt), do: if_opt.()
  defp enabled?(true), do: true
  defp enabled?(_), do: false

  defp invalid_path?(list) do
    invalid_path?(list, :binary.compile_pattern(["/", "\\", ":", "\0"]))
  end

  defp invalid_path?([h | _], _match) when h in [".", "..", ""], do: true
  defp invalid_path?([h | t], match), do: String.contains?(h, match) or invalid_path?(t)
  defp invalid_path?([], _match), do: false

  defp api_route?([]), do: false

  defp api_route?([h | t]) do
    api_routes = Pleroma.Web.Router.get_api_routes()
    if h in api_routes, do: true, else: api_route?(t)
  end

  defp call_static(conn, opts, from) do
    opts = Map.put(opts, :from, from)
    Plug.Static.call(conn, opts)
  end
end
