# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UploadedMedia do
  @moduledoc """
  """

  import Plug.Conn
  import Pleroma.Web.Gettext
  require Logger

  @behaviour Plug
  # no slashes
  @path "media"

  @default_cache_control_header "public, max-age=1209600"

  def init(_opts) do
    static_plug_opts =
      [
        headers: %{"cache-control" => @default_cache_control_header},
        cache_control_for_etags: @default_cache_control_header
      ]
      |> Keyword.put(:from, "__unconfigured_media_plug")
      |> Keyword.put(:at, "/__unconfigured_media_plug")
      |> Plug.Static.init()

    %{static_plug_opts: static_plug_opts}
  end

  def call(%{request_path: <<"/", @path, "/", file::binary>>} = conn, opts) do
    conn =
      case fetch_query_params(conn) do
        %{query_params: %{"name" => name}} = conn ->
          name = String.replace(name, "\"", "\\\"")

          conn
          |> put_resp_header("content-disposition", "filename=\"#{name}\"")

        conn ->
          conn
      end

    config = Pleroma.Config.get(Pleroma.Upload)

    with uploader <- Keyword.fetch!(config, :uploader),
         proxy_remote = Keyword.get(config, :proxy_remote, false),
         {:ok, get_method} <- uploader.get_file(file) do
      get_media(conn, get_method, proxy_remote, opts)
    else
      _ ->
        conn
        |> send_resp(:internal_server_error, dgettext("errors", "Failed"))
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp get_media(conn, {:static_dir, directory}, _, opts) do
    static_opts =
      Map.get(opts, :static_plug_opts)
      |> Map.put(:at, [@path])
      |> Map.put(:from, directory)

    conn = Plug.Static.call(conn, static_opts)

    if conn.halted do
      conn
    else
      conn
      |> send_resp(:not_found, dgettext("errors", "Not found"))
      |> halt()
    end
  end

  defp get_media(conn, {:url, url}, true, _) do
    conn
    |> Pleroma.ReverseProxy.call(url, Pleroma.Config.get([Pleroma.Upload, :proxy_opts], []))
  end

  defp get_media(conn, {:url, url}, _, _) do
    conn
    |> Phoenix.Controller.redirect(external: url)
    |> halt()
  end

  defp get_media(conn, unknown, _, _) do
    Logger.error("#{__MODULE__}: Unknown get startegy: #{inspect(unknown)}")

    conn
    |> send_resp(:internal_server_error, dgettext("errors", "Internal Error"))
    |> halt()
  end
end
