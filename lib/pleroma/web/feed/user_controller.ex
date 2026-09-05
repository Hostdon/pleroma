# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.UserController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.ActivityPubController
  alias Pleroma.Web.Feed.FeedView

  plug(Pleroma.Web.Plugs.SetFormatPlug when action in [:feed_redirect])

  action_fallback(:errors)

  def feed_redirect(%{assigns: %{format: format}} = conn, _params)
      when format in ["json", "activity+json"] do
    ActivityPubController.call(conn, :user)
  end

  # redirect from new AP id route
  def feed_redirect(conn, %{"user_id" => id}) do
    user = User.get_cached_by_id(id)
    redirect_html_or_feed(conn, user)
  end

  # redirect from static-fe or legacy AP id route
  def feed_redirect(conn, %{"nickname" => nickname}) do
    user = User.get_cached_by_nickname(nickname)
    redirect_html_or_feed(conn, user)
  end

  defp redirect_html_or_feed(%{assigns: %{format: "html"}} = conn, %User{} = user) do
    Pleroma.Web.Fallback.RedirectController.redirector_with_meta(conn, %{user: user})
  end

  defp redirect_html_or_feed(%{assigns: %{format: "html"}} = conn, _) do
    Pleroma.Web.Fallback.RedirectController.redirector(conn, nil)
  end

  defp redirect_html_or_feed(%{assigns: assigns} = conn, %User{} = user) do
    format = Map.get(assigns, :format, "atom")
    format = if format in ["atom", "rss"], do: format, else: "atom"

    redirect(conn, external: "#{url(~p"/users/by-id/#{user.id}/feed")}.#{format}")
  end

  defp redirect_html_or_feed(_conn, _user), do: {:error, :not_found}

  def feed(conn, %{"user_id" => id} = params) do
    user = User.get_cached_by_id(id)
    render_feed(conn, params, user)
  end

  # legacy route; deprecated since unstable when nickname is updated
  def feed(conn, %{"nickname" => nickname} = params) do
    user = User.get_cached_by_nickname(nickname)
    render_feed(conn, params, user)
  end

  defp render_feed(_, _, nil), do: {:error, :not_found}
  defp render_feed(_, _, %User{local: false}), do: {:error, :not_found}

  defp render_feed(conn, params, user) do
    format = get_format(conn)

    format =
      if format in ["atom", "rss"] do
        format
      else
        "atom"
      end

    with {_, :visible} <- {:visibility, User.visible_for(user, _reading_user = nil)} do
      activities =
        %{
          type: ["Create"],
          actor_id: user.ap_id
        }
        |> Pleroma.Maps.put_if_present(:max_id, params["max_id"])
        |> ActivityPub.fetch_public_or_unlisted_activities()

      conn
      |> put_resp_content_type("application/#{format}+xml")
      |> put_view(FeedView)
      |> render("user.#{format}",
        user: user,
        activities: activities,
        feed_config: Config.get([:feed]),
        view_module: FeedView
      )
    else
      _ -> {:error, :not_found}
    end
  end

  def errors(conn, {:error, :not_found}) do
    render_error(conn, :not_found, "Not found")
  end

  def errors(conn, {:fetch_user, %User{local: false}}), do: errors(conn, {:error, :not_found})
  def errors(conn, {:fetch_user, nil}), do: errors(conn, {:error, :not_found})

  def errors(conn, {:visibility, _}), do: errors(conn, {:error, :not_found})

  def errors(conn, _) do
    render_error(conn, :internal_server_error, "Something went wrong")
  end
end
