# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.FederatingPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, opts) do
    if federating?() do
      conn
    else
      fail(conn, opts)
    end
  end

  def federating?, do: Pleroma.Config.get([:instance, :federating])

  # Definition for the use in :if_func / :unless_func plug options
  def federating?(_conn), do: federating?()

  defp fail(conn, opts) do
    status = Keyword.get(opts, :fail_status, 404)

    conn
    |> put_status(status)
    |> Phoenix.Controller.put_view(Pleroma.Web.ErrorView)
    |> Phoenix.Controller.render("404.json")
    |> halt()
  end
end
