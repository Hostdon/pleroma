# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.InstanceStatic do
  import Plug.Conn

  require Pleroma.Constants

  alias Pleroma.Web.Plugs.Utils

  @moduledoc """
  This is a shim to call `Plug.Static` but with runtime `from` configuration.

  Mountpoints are defined directly in the module to avoid calling the configuration for every request including non-static ones.
  """
  @behaviour Plug

  def file_path(path, frontend_type \\ :primary) do
    instance_path =
      Path.join(Pleroma.Config.get([:instance, :static_dir], "instance/static/"), path)

    frontend_path = Pleroma.Web.Plugs.FrontendStatic.file_path(path, frontend_type)

    (File.exists?(instance_path) && instance_path) ||
      (frontend_path && File.exists?(frontend_path) && frontend_path) ||
      Path.join(Application.app_dir(:pleroma, "priv/static/"), path)
  end

  def init(opts) do
    opts
    |> Keyword.put(:from, "__unconfigured_instance_static_plug")
    |> Plug.Static.init()
  end

  for only <- Pleroma.Constants.static_only_files() do
    def call(%{request_path: "/" <> unquote(only) <> _} = conn, opts) do
      call_static(
        conn,
        opts,
        Pleroma.Config.get([:instance, :static_dir], "instance/static")
      )
    end
  end

  def call(conn, _) do
    conn
  end

  defp set_static_content_type(conn, "/emoji/" <> _ = request_path) do
    real_mime = MIME.from_path(request_path)
    safe_mime = Utils.get_safe_mime_type(%{allowed_mime_types: ["image"]}, real_mime)

    put_resp_header(conn, "content-type", safe_mime)
  end

  defp set_static_content_type(conn, request_path) do
    put_resp_header(conn, "content-type", MIME.from_path(request_path))
  end

  defp call_static(%{request_path: request_path} = conn, opts, from) do
    opts =
      opts
      |> Map.put(:from, from)
      |> Map.put(:set_content_type, false)

    conn
    |> set_static_content_type(request_path)
    |> Pleroma.Web.Plugs.StaticNoCT.call(opts)
  end
end
