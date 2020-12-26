# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug do
  import Pleroma.Web.TranslationHelpers
  import Plug.Conn

  alias Pleroma.Config
  alias Pleroma.User

  use Pleroma.Web, :plug

  def init(options) do
    options
  end

  @impl true
  def perform(conn, _) do
    public? = Config.get!([:instance, :public])

    case {public?, conn} do
      {true, _} ->
        conn

      {false, %{assigns: %{user: %User{}}}} ->
        conn

      {false, _} ->
        conn
        |> render_error(:forbidden, "This resource requires authentication.")
        |> halt
    end
  end
end
