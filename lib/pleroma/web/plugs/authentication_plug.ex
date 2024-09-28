# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.AuthenticationPlug do
  @moduledoc "Password authentication plug."

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.User
  alias Pleroma.Password

  import Plug.Conn

  require Logger

  def init(options), do: options

  def call(%{assigns: %{user: %User{}}} = conn, _), do: conn

  def call(
        %{
          assigns: %{
            auth_user: %{password_hash: password_hash} = auth_user,
            auth_credentials: %{password: password}
          }
        } = conn,
        _
      ) do
    if Password.checkpw(password, password_hash) do
      {:ok, auth_user} = Password.maybe_update_password(auth_user, password)

      conn
      |> assign(:user, auth_user)
      |> AuthHelper.skip_oauth()
    else
      conn
    end
  end

  def call(conn, _), do: conn

  @spec checkpw(String.t(), String.t()) :: boolean
  defdelegate checkpw(password, hash), to: Password
end
