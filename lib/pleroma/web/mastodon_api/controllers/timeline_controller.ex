# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.TimelineController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [add_link_headers: 2, add_link_headers: 3]

  alias Pleroma.Config
  alias Pleroma.Pagination
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  plug(:skip_public_check when action in [:public, :hashtag, :bubble])

  # TODO: Replace with a macro when there is a Phoenix release with the following commit in it:
  # https://github.com/phoenixframework/phoenix/commit/2e8c63c01fec4dde5467dbbbf9705ff9e780735e

  plug(RateLimiter, [name: :timeline, bucket_name: :direct_timeline] when action == :direct)
  plug(RateLimiter, [name: :timeline, bucket_name: :public_timeline] when action == :public)
  plug(RateLimiter, [name: :timeline, bucket_name: :home_timeline] when action == :home)
  plug(RateLimiter, [name: :timeline, bucket_name: :hashtag_timeline] when action == :hashtag)
  plug(RateLimiter, [name: :timeline, bucket_name: :list_timeline] when action == :list)
  plug(RateLimiter, [name: :timeline, bucket_name: :bubble_timeline] when action == :bubble)

  plug(OAuthScopesPlug, %{scopes: ["read:statuses"]} when action in [:home, :direct])
  plug(OAuthScopesPlug, %{scopes: ["read:lists"]} when action == :list)

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:statuses"], fallback: :proceed_unauthenticated}
    when action in [:public, :hashtag, :bubble]
  )

  require Logger

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.TimelineOperation

  # GET /api/v1/timelines/home
  def home(%{assigns: %{user: user}} = conn, params) do
    %{nickname: nickname} = user

    Logger.debug("TimelineController.home: #{nickname}")

    followed_hashtags =
      user
      |> User.followed_hashtags()
      |> Enum.map(& &1.id)

    params =
      params
      |> Map.put(:type, ["Create", "Announce"])
      |> Map.put(:blocking_user, user)
      |> Map.put(:muting_user, user)
      |> Map.put(:reply_filtering_user, user)
      |> Map.put(:announce_filtering_user, user)
      |> Map.put(:user, user)
      |> Map.put(:local_only, params[:local])
      |> Map.put(:followed_hashtags, followed_hashtags)
      |> Map.delete(:local)

    Logger.debug("TimelineController.home: #{nickname} - fetching activities")

    activities =
      [user.ap_id | User.following(user)]
      |> ActivityPub.fetch_activities(params)
      |> Enum.reverse()

    Logger.debug("TimelineController.home: #{nickname} - rendering")

    conn
    |> add_link_headers(activities)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity,
      with_muted: Map.get(params, :with_muted, false)
    )
  end

  # GET /api/v1/timelines/direct
  def direct(%{assigns: %{user: user}} = conn, params) do
    Logger.debug("TimelineController.direct: #{user.nickname}")

    params =
      params
      |> Map.put(:type, "Create")
      |> Map.put(:blocking_user, user)
      |> Map.put(:user, user)
      |> Map.put(:visibility, "direct")

    Logger.debug("TimelineController.direct: #{user.nickname} - fetching activities")

    activities =
      [user.ap_id]
      |> ActivityPub.fetch_activities_query(params)
      |> Pagination.fetch_paginated(params)

    Logger.debug("TimelineController.direct: #{user.nickname} - rendering")

    conn
    |> add_link_headers(activities)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity
    )
  end

  defp restrict_unauthenticated?(type) do
    Config.restrict_unauthenticated_access?(:timelines, type)
  end

  # GET /api/v1/timelines/public
  def public(%{assigns: %{user: user}} = conn, params) do
    Logger.debug("TimelineController.public")
    local_only = params[:local]
    timeline_type = if local_only, do: :local, else: :federated

    with {:enabled, true} <-
           {:enabled, local_only || Config.get([:instance, :federated_timeline_available], true)},
         {:authenticated, true} <-
           {:authenticated, !(is_nil(user) and restrict_unauthenticated?(timeline_type))} do
      Logger.debug("TimelineController.public: fetching activities")

      activities =
        params
        |> Map.put(:type, ["Create"])
        |> Map.put(:local_only, local_only)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:instance, params[:instance])
        # Restricts unfederated content to authenticated users
        |> Map.put(:includes_local_public, not is_nil(user))
        |> ActivityPub.fetch_public_activities()

      Logger.debug("TimelineController.public: rendering")

      conn
      |> add_link_headers(activities, %{"local" => local_only})
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      {:enabled, false} ->
        conn
        |> put_status(404)
        |> json(%{error: "Federated timeline is disabled"})

      {:authenticated, false} ->
        fail_on_bad_auth(conn)
    end
  end

  # GET /api/v1/timelines/bubble
  def bubble(%{assigns: %{user: user}} = conn, params) do
    Logger.debug("TimelineController.bubble")

    if is_nil(user) and restrict_unauthenticated?(:bubble) do
      fail_on_bad_auth(conn)
    else
      bubble_instances =
        Enum.uniq(
          Config.get([:instance, :local_bubble], []) ++
            [Pleroma.Web.Endpoint.host()]
        )

      Logger.debug("TimelineController.bubble: fetching activities")

      activities =
        params
        |> Map.put(:type, ["Create"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:instance, bubble_instances)
        |> ActivityPub.fetch_public_activities()

      Logger.debug("TimelineController.bubble: rendering")

      conn
      |> add_link_headers(activities)
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    end
  end

  defp fail_on_bad_auth(conn) do
    render_error(conn, :unauthorized, "authorization required for timeline view")
  end

  defp hashtag_fetching(params, user, local_only) do
    # Note: not sanitizing tag options at this stage (may be mix-cased, have duplicates etc.)
    tags_any =
      [params[:tag], params[:any]]
      |> List.flatten()
      |> Enum.filter(& &1)

    tag_all = Map.get(params, :all, [])
    tag_reject = Map.get(params, :none, [])

    params
    |> Map.put(:type, "Create")
    |> Map.put(:local_only, local_only)
    |> Map.put(:blocking_user, user)
    |> Map.put(:muting_user, user)
    |> Map.put(:user, user)
    |> Map.put(:tag, tags_any)
    |> Map.put(:tag_all, tag_all)
    |> Map.put(:tag_reject, tag_reject)
    |> ActivityPub.fetch_public_activities()
  end

  # GET /api/v1/timelines/tag/:tag
  def hashtag(%{assigns: %{user: user}} = conn, params) do
    local_only = params[:local]

    if is_nil(user) and restrict_unauthenticated?(if local_only, do: :local, else: :federated) do
      fail_on_bad_auth(conn)
    else
      activities = hashtag_fetching(params, user, local_only)

      conn
      |> add_link_headers(activities, %{"local" => local_only})
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    end
  end

  # GET /api/v1/timelines/list/:list_id
  def list(%{assigns: %{user: user}} = conn, %{list_id: id} = params) do
    with %Pleroma.List{title: _title, following: following} <- Pleroma.List.get(id, user) do
      params =
        params
        |> Map.put(:type, "Create")
        |> Map.put(:blocking_user, user)
        |> Map.put(:user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:local_only, params[:local])

      # we must filter the following list for the user to avoid leaking statuses the user
      # does not actually have permission to see (for more info, peruse security issue #270).

      user_following = User.following(user)

      activities =
        following
        |> Enum.filter(fn x -> x in user_following end)
        |> ActivityPub.fetch_activities_bounded(following, params)
        |> Enum.reverse()

      conn
      |> add_link_headers(activities)
      |> render("index.json",
        activities: activities,
        for: user,
        as: :activity,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      _e -> render_error(conn, :forbidden, "Error.")
    end
  end
end
