# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.StatusController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper,
    only: [try_render: 3, add_link_headers: 2]

  require Ecto.Query

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Config
  alias Pleroma.ScheduledActivity
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.ScheduledActivityView
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.RateLimiter

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(:skip_public_check when action in [:index, :show])

  @unauthenticated_access %{fallback: :proceed_unauthenticated, scopes: []}
  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:statuses"]}
    when action in [
           :index,
           :show,
           :context,
           :translate,
           :translate_legacy,
           :show_history,
           :show_source
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:statuses"]}
    when action in [
           :create,
           :delete,
           :reblog,
           :unreblog,
           :update
         ]
  )

  plug(OAuthScopesPlug, %{scopes: ["read:favourites"]} when action == :favourites)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:favourites"]} when action in [:favourite, :unfavourite]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:mutes"]} when action in [:mute_conversation, :unmute_conversation]
  )

  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:accounts"]}
    when action in [:favourited_by, :reblogged_by]
  )

  plug(OAuthScopesPlug, %{scopes: ["write:accounts"]} when action in [:pin, :unpin])

  # Note: scope not present in Mastodon: read:bookmarks
  plug(OAuthScopesPlug, %{scopes: ["read:bookmarks"]} when action == :bookmarks)

  # Note: scope not present in Mastodon: write:bookmarks
  plug(
    OAuthScopesPlug,
    %{scopes: ["write:bookmarks"]} when action in [:bookmark, :unbookmark]
  )

  @rate_limited_status_actions ~w(reblog unreblog favourite unfavourite create delete update)a

  plug(
    RateLimiter,
    [name: :status_id_action, bucket_name: "status_id_action:reblog_unreblog", params: [:id]]
    when action in ~w(reblog unreblog)a
  )

  plug(
    RateLimiter,
    [name: :status_id_action, bucket_name: "status_id_action:fav_unfav", params: [:id]]
    when action in ~w(favourite unfavourite)a
  )

  plug(RateLimiter, [name: :statuses_actions] when action in @rate_limited_status_actions)

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.StatusOperation

  @doc """
  GET `/api/v1/statuses?ids[]=1&ids[]=2`

  `ids` query param is required
  """
  def index(%{assigns: %{user: user}} = conn, %{ids: ids} = params) do
    limit = 100

    activities =
      ids
      |> Enum.take(limit)
      |> Activity.all_by_ids_with_object()
      |> Enum.filter(&Visibility.visible_for_user?(&1, user))

    render(conn, "index.json",
      activities: activities,
      for: user,
      as: :activity,
      with_muted: Map.get(params, :with_muted, false)
    )
  end

  @doc """
  POST /api/v1/statuses
  """
  # Creates a scheduled status when `scheduled_at` param is present and it's far enough
  def create(
        %Plug.Conn{
          assigns: %{user: user},
          body_params: %{status: _, scheduled_at: scheduled_at} = params
        } = conn,
        _
      )
      when not is_nil(scheduled_at) do
    params =
      Map.put(params, :in_reply_to_status_id, params[:in_reply_to_id])
      |> put_application(conn)

    attrs = %{
      params: Map.new(params, fn {key, value} -> {to_string(key), value} end),
      scheduled_at: scheduled_at
    }

    with {:far_enough, true} <- {:far_enough, ScheduledActivity.far_enough?(scheduled_at)},
         {:ok, scheduled_activity} <- ScheduledActivity.create(user, attrs) do
      conn
      |> put_view(ScheduledActivityView)
      |> render("show.json", scheduled_activity: scheduled_activity)
    else
      {:far_enough, _} ->
        params = Map.drop(params, [:scheduled_at])
        create(%Plug.Conn{conn | body_params: params}, %{})

      error ->
        error
    end
  end

  # Creates a regular status
  def create(%{assigns: %{user: user}, body_params: %{status: _} = params} = conn, _) do
    params =
      Map.put(params, :in_reply_to_status_id, params[:in_reply_to_id])
      |> put_application(conn)

    expires_in_seconds =
      Map.get(params, :expires_in) ||
        (user.status_ttl_days && 60 * 60 * 24 * user.status_ttl_days)

    params =
      case expires_in_seconds do
        nil -> params
        0 -> Map.delete(params, :expires_in)
        _ -> Map.put(params, :expires_in, expires_in_seconds)
      end

    with {:ok, activity} <- CommonAPI.post(user, params) do
      try_render(conn, "show.json",
        activity: activity,
        for: user,
        as: :activity,
        with_direct_conversation_id: true
      )
    else
      {:error, {:reject, message}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  def create(%Plug.Conn{assigns: %{user: _user}, body_params: %{media_ids: _} = params} = conn, _) do
    params = Map.put(params, :status, "")
    create(%Plug.Conn{conn | body_params: params}, %{})
  end

  @doc "GET /api/v1/statuses/:id/history"
  def show_history(%{assigns: assigns} = conn, %{id: id} = params) do
    with user = assigns[:user],
         %Activity{} = activity <- Activity.get_by_id_with_object(id),
         true <- Visibility.visible_for_user?(activity, user) do
      try_render(conn, "history.json",
        activity: activity,
        for: user,
        with_direct_conversation_id: true,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "GET /api/v1/statuses/:id/source"
  def show_source(%{assigns: assigns} = conn, %{id: id} = _params) do
    with user = assigns[:user],
         %Activity{} = activity <- Activity.get_by_id_with_object(id),
         true <- Visibility.visible_for_user?(activity, user) do
      try_render(conn, "source.json",
        activity: activity,
        for: user
      )
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "PUT /api/v1/statuses/:id"
  def update(%{assigns: %{user: user}, body_params: body_params} = conn, %{id: id} = params) do
    with {_, %Activity{}} = {_, activity} <- {:activity, Activity.get_by_id_with_object(id)},
         {_, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         {_, true} <- {:is_create, activity.data["type"] == "Create"},
         actor <- Activity.user_actor(activity),
         {_, true} <- {:own_status, actor.id == user.id},
         changes <- body_params |> put_application(conn),
         {_, {:ok, _update_activity}} <- {:pipeline, CommonAPI.update(user, activity, changes)},
         {_, %Activity{}} = {_, activity} <- {:refetched, Activity.get_by_id_with_object(id)} do
      try_render(conn, "show.json",
        activity: activity,
        for: user,
        with_direct_conversation_id: true,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      {:own_status, _} -> {:error, :forbidden}
      {:pipeline, _} -> {:error, :internal_server_error}
      _ -> {:error, :not_found}
    end
  end

  @doc "GET /api/v1/statuses/:id"
  def show(%{assigns: %{user: user}} = conn, %{id: id} = params) do
    # Announces are handled as normal statuses in MastoAPI, they just put the reblogged post
    # in a "reblog" subproperty which clients the use for display. Creates are trivially ok.
    # Everything else isn’t a status as far as MastoAPI is concerned and
    # would show up buggy since it’s not expected by our JSON render, thus reject.
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         type when type in ["Create", "Announce"] <- activity.data["type"],
         true <- Visibility.visible_for_user?(activity, user) do
      try_render(conn, "show.json",
        activity: activity,
        for: user,
        with_direct_conversation_id: true,
        with_muted: Map.get(params, :with_muted, false)
      )
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "DELETE /api/v1/statuses/:id"
  def delete(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         # CommonAPI already chcks whether user is allowed to delete
         {:ok, %Activity{}} <- CommonAPI.delete(id, user) do
      try_render(conn, "show.json",
        activity: activity,
        for: user,
        with_direct_conversation_id: true,
        with_source: true
      )
    else
      _e -> {:error, :not_found}
    end
  end

  @doc "POST /api/v1/statuses/:id/reblog"
  def reblog(%{assigns: %{user: user}, body_params: params} = conn, %{id: ap_id_or_id}) do
    # CommonAPI checks if allowed to reblog
    with {:ok, announce} <- CommonAPI.repeat(ap_id_or_id, user, params),
         %Activity{} = announce <- Activity.normalize(announce.data) do
      try_render(conn, "show.json", %{activity: announce, for: user, as: :activity})
    end
  end

  @doc "POST /api/v1/statuses/:id/unreblog"
  def unreblog(%{assigns: %{user: user}} = conn, %{id: activity_id}) do
    with {:ok, _unannounce} <- CommonAPI.unrepeat(activity_id, user),
         %Activity{} = activity <- Activity.get_by_id(activity_id) do
      try_render(conn, "show.json", %{activity: activity, for: user, as: :activity})
    end
  end

  @doc "POST /api/v1/statuses/:id/favourite"
  def favourite(%{assigns: %{user: user}} = conn, %{id: activity_id}) do
    # CommonAPI checks if allowed to fav
    with {:ok, _fav} <- CommonAPI.favorite(user, activity_id),
         %Activity{} = activity <- Activity.get_by_id(activity_id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/unfavourite"
  def unfavourite(%{assigns: %{user: user}} = conn, %{id: activity_id}) do
    with {:ok, _unfav} <- CommonAPI.unfavorite(activity_id, user),
         %Activity{} = activity <- Activity.get_by_id(activity_id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    end
  end

  @doc "POST /api/v1/statuses/:id/pin"
  def pin(%{assigns: %{user: user}} = conn, %{id: ap_id_or_id}) do
    with {:ok, activity} <- CommonAPI.pin(ap_id_or_id, user) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    else
      {:error, :pinned_statuses_limit_reached} ->
        {:error, "You have already pinned the maximum number of statuses"}

      {:error, :ownership_error} ->
        {:error, :unprocessable_entity, "Someone else's status cannot be pinned"}

      {:error, :visibility_error} ->
        {:error, :unprocessable_entity, "Non-public status cannot be pinned"}

      error ->
        error
    end
  end

  @doc "POST /api/v1/statuses/:id/unpin"
  def unpin(%{assigns: %{user: user}} = conn, %{id: ap_id_or_id}) do
    # CommonAPI already checks whether user can unpin
    with {:ok, activity} <- CommonAPI.unpin(ap_id_or_id, user) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    else
      {:error, :ownership_error} ->
        {:error, :unprocessable_entity, "Someone else's status cannot be unpinned"}

      error ->
        error
    end
  end

  @doc "POST /api/v1/statuses/:id/bookmark"
  def bookmark(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         %User{} = user <- User.get_cached_by_nickname(user.nickname),
         true <- Visibility.visible_for_user?(activity, user),
         {:ok, _bookmark} <- Bookmark.create(user.id, activity.id) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    else
      none when none in [nil, false] ->
        {:error, :not_found, "Record not found"}

      error ->
        error
    end
  end

  @doc "POST /api/v1/statuses/:id/unbookmark"
  def unbookmark(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         %User{} = user <- User.get_cached_by_nickname(user.nickname),
         # order matters: if a user bookmarked a post but later lost access rights via unfollow
         # we want to allow cleaning up the now useless entry (if it was still cached locally)
         # but never return a success response which contains the current status content
         :ok <- Bookmark.destroy(user.id, activity.id),
         true <- Visibility.visible_for_user?(activity, user) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    else
      none when none in [nil, false] ->
        {:error, :not_found, "Record not found"}

      error ->
        error
    end
  end

  @doc "POST /api/v1/statuses/:id/mute"
  def mute_conversation(%{assigns: %{user: user}, body_params: params} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         # CommonAPI already checks whether user is allowed to mute
         {:ok, activity} <- CommonAPI.add_mute(user, activity, params) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    else
      {:error, :visibility_error} ->
        {:error, :not_found, "Record not found"}

      error ->
        error
    end
  end

  @doc "POST /api/v1/statuses/:id/unmute"
  def unmute_conversation(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         # CommonAPI already checks whether user is allowed to unmute
         {:ok, activity} <- CommonAPI.remove_mute(user, activity) do
      try_render(conn, "show.json", activity: activity, for: user, as: :activity)
    else
      {:error, :visibility_error} ->
        {:error, :not_found, "Record not found"}

      error ->
        error
    end
  end

  @doc "GET /api/v1/statuses/:id/favourited_by"
  def favourited_by(%{assigns: %{user: user}} = conn, %{id: id}) do
    with true <- Pleroma.Config.get([:instance, :show_reactions]),
         %Activity{} = activity <- Activity.get_by_id_with_object(id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         %Object{data: %{"likes" => likes}} <- Object.normalize(activity, fetch: false) do
      users =
        User
        |> Ecto.Query.where([u], u.ap_id in ^likes)
        |> Repo.all()
        |> Enum.filter(&(not User.blocks?(user, &1)))

      conn
      |> put_view(AccountView)
      |> render("index.json", for: user, users: users, as: :user)
    else
      {:visible, false} -> {:error, :not_found}
      _ -> json(conn, [])
    end
  end

  @doc "GET /api/v1/statuses/:id/reblogged_by"
  def reblogged_by(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id_with_object(id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         %Object{data: %{"announcements" => announces, "id" => ap_id}} <-
           Object.normalize(activity, fetch: false) do
      announces =
        "Announce"
        |> Activity.Queries.by_type()
        |> Ecto.Query.where([a], a.actor in ^announces)
        # this is to use the index
        |> Activity.Queries.by_object_id(ap_id)
        |> Repo.all()
        |> Enum.filter(&Visibility.visible_for_user?(&1, user))
        |> Enum.map(& &1.actor)
        |> Enum.uniq()

      users =
        User
        |> Ecto.Query.where([u], u.ap_id in ^announces)
        |> Repo.all()
        |> Enum.filter(&(not User.blocks?(user, &1)))

      conn
      |> put_view(AccountView)
      |> render("index.json", for: user, users: users, as: :user)
    else
      {:visible, false} -> {:error, :not_found}
      _ -> json(conn, [])
    end
  end

  @doc "GET /api/v1/statuses/:id/context"
  def context(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %Activity{} = activity <- Activity.get_by_id(id),
         true <- Visibility.visible_for_user?(activity, user) do
      activities =
        activity.data["context"]
        |> ActivityPub.fetch_activities_for_context(%{
          blocking_user: user,
          user: user,
          with_muted: true,
          exclude_id: activity.id
        })
        |> Enum.filter(fn activity -> Visibility.visible_for_user?(activity, user) end)

      render(conn, "context.json", activity: activity, activities: activities, user: user)
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "GET /api/v1/favourites"
  def favourites(%{assigns: %{user: %User{} = user}} = conn, params) do
    activities_keyed = ActivityPub.fetch_favourited_with_fav_id(user, params)
    activities = Pleroma.Pagination.unwrap(activities_keyed)

    conn
    |> add_link_headers(activities_keyed)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity
    )
  end

  @doc "GET /api/v1/bookmarks"
  def bookmarks(%{assigns: %{user: user}} = conn, params) do
    user = User.get_cached_by_id(user.id)

    bookmarks =
      user.id
      |> Bookmark.for_user_query()
      |> Pleroma.Pagination.fetch_paginated(params)

    activities =
      bookmarks
      |> Enum.map(fn b -> Map.put(b.activity, :bookmark, Map.delete(b, :activity)) end)

    conn
    |> add_link_headers(bookmarks)
    |> render("index.json",
      activities: activities,
      for: user,
      as: :activity
    )
  end

  @doc "POST /api/v1/statuses/:id/translate"
  def translate(%{assigns: %{user: user}, body_params: params} = conn, %{id: id}) do
    with {:ok, translation} <-
           do_translate(
             id,
             user,
             Map.get(params, :source_lang, nil),
             Map.get(params, :lang, nil)
           ) do
      json(conn, translation)
    else
      {:enabled, false} ->
        conn
        |> put_status(:forbidden)
        |> json(%{"error" => "Translation is not enabled"})

      {:visible, false} ->
        {:error, :not_found}

      e ->
        e
    end
  end

  @doc "GET /api/v1/statuses/:id/translations/:language"
  def translate_legacy(%{assigns: %{user: user}} = conn, %{id: id, language: language} = params) do
    with {:ok, %{content: translation, detected_source_language: detected}} <-
           do_translate(id, user, Map.get(params, :from, nil), language) do
      json(conn, %{detected_language: detected, text: translation})
    else
      {:enabled, false} ->
        conn
        |> put_status(:bad_request)
        |> json(%{"error" => "Translation is not enabled"})

      {:visible, false} ->
        {:error, :not_found}

      e ->
        e
    end
  end

  defp do_translate(id, user, source_language, target_language) do
    with {:enabled, true} <- {:enabled, Config.get([:translator, :enabled])},
         %Activity{} = activity <- Activity.get_by_id_with_object(id),
         {:visible, true} <- {:visible, Visibility.visible_for_user?(activity, user)},
         translation_module <- Config.get([:translator, :module]),
         {:ok, detected, translation} <-
           fetch_or_translate(
             activity.id,
             activity.object.data["content"],
             source_language,
             target_language,
             translation_module
           ) do
      {:ok,
       %{
         content: translation,
         detected_source_language: detected,
         provider: translation_module.name()
       }}
    end
  end

  defp fetch_or_translate(status_id, text, source_language, target_language, translation_module) do
    @cachex.fetch!(
      :translations_cache,
      "translations:#{status_id}:#{source_language}:#{target_language}",
      fn _ ->
        value = translation_module.translate(text, source_language, target_language)

        with {:ok, _, _} <- value do
          {:commit, value}
        else
          _ -> {:ignore, value}
        end
      end
    )
  end

  defp put_application(params, %{assigns: %{token: %Token{user: %User{} = user} = token}} = _conn) do
    if user.disclose_client do
      %{client_name: client_name, website: website} = Repo.preload(token, :app).app
      Map.put(params, :generator, %{type: "Application", name: client_name, url: website})
    else
      Map.put(params, :generator, nil)
    end
  end

  defp put_application(params, _), do: Map.put(params, :generator, nil)
end
