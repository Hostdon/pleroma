# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Activity
  alias Pleroma.Activity.Ir.Topics
  alias Pleroma.Config
  alias Pleroma.Constants
  alias Pleroma.Conversation
  alias Pleroma.Conversation.Participation
  alias Pleroma.Filter
  alias Pleroma.Maps
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Object.Fetcher
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.Upload
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.Streamer
  alias Pleroma.Web.WebFinger
  alias Pleroma.Workers.BackgroundWorker

  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  import Pleroma.Web.ActivityPub.Visibility

  require Logger
  require Pleroma.Constants

  defp get_recipients(%{"type" => "Create"} = data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    actor = Map.get(data, "actor", [])
    recipients = [to, cc, bcc, [actor]] |> Enum.concat() |> Enum.uniq()
    {recipients, to, cc}
  end

  defp get_recipients(data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    recipients = Enum.concat([to, cc, bcc])
    {recipients, to, cc}
  end

  defp check_actor_is_active(nil), do: true

  defp check_actor_is_active(actor) when is_binary(actor) do
    case User.get_cached_by_ap_id(actor) do
      %User{deactivated: deactivated} -> not deactivated
      _ -> false
    end
  end

  defp check_remote_limit(%{"object" => %{"content" => content}}) when not is_nil(content) do
    limit = Config.get([:instance, :remote_limit])
    String.length(content) <= limit
  end

  defp check_remote_limit(_), do: true

  def increase_note_count_if_public(actor, object) do
    if is_public?(object), do: User.increase_note_count(actor), else: {:ok, actor}
  end

  def decrease_note_count_if_public(actor, object) do
    if is_public?(object), do: User.decrease_note_count(actor), else: {:ok, actor}
  end

  defp increase_replies_count_if_reply(%{
         "object" => %{"inReplyTo" => reply_ap_id} = object,
         "type" => "Create"
       }) do
    if is_public?(object) do
      Object.increase_replies_count(reply_ap_id)
    end
  end

  defp increase_replies_count_if_reply(_create_data), do: :noop

  @object_types ~w[ChatMessage Question Answer Audio Video Event Article]
  @spec persist(map(), keyword()) :: {:ok, Activity.t() | Object.t()}
  def persist(%{"type" => type} = object, meta) when type in @object_types do
    with {:ok, object} <- Object.create(object) do
      {:ok, object, meta}
    end
  end

  def persist(object, meta) do
    with local <- Keyword.fetch!(meta, :local),
         {recipients, _, _} <- get_recipients(object),
         {:ok, activity} <-
           Repo.insert(%Activity{
             data: object,
             local: local,
             recipients: recipients,
             actor: object["actor"]
           }),
         # TODO: add tests for expired activities, when Note type will be supported in new pipeline
         {:ok, _} <- maybe_create_activity_expiration(activity) do
      {:ok, activity, meta}
    end
  end

  @spec insert(map(), boolean(), boolean(), boolean()) :: {:ok, Activity.t()} | {:error, any()}
  def insert(map, local \\ true, fake \\ false, bypass_actor_check \\ false) when is_map(map) do
    with nil <- Activity.normalize(map),
         map <- lazy_put_activity_defaults(map, fake),
         {_, true} <- {:actor_check, bypass_actor_check || check_actor_is_active(map["actor"])},
         {_, true} <- {:remote_limit_pass, check_remote_limit(map)},
         {:ok, map} <- MRF.filter(map),
         {recipients, _, _} = get_recipients(map),
         {:fake, false, map, recipients} <- {:fake, fake, map, recipients},
         {:containment, :ok} <- {:containment, Containment.contain_child(map)},
         {:ok, map, object} <- insert_full_object(map),
         {:ok, activity} <- insert_activity_with_expiration(map, local, recipients) do
      # Splice in the child object if we have one.
      activity = Maps.put_if_present(activity, :object, object)

      BackgroundWorker.enqueue("fetch_data_for_activity", %{"activity_id" => activity.id})

      {:ok, activity}
    else
      %Activity{} = activity ->
        {:ok, activity}

      {:actor_check, _} ->
        {:error, false}

      {:containment, _} = error ->
        error

      {:error, _} = error ->
        error

      {:fake, true, map, recipients} ->
        activity = %Activity{
          data: map,
          local: local,
          actor: map["actor"],
          recipients: recipients,
          id: "pleroma:fakeid"
        }

        Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)
        {:ok, activity}

      {:remote_limit_pass, _} ->
        {:error, :remote_limit}

      {:reject, _} = e ->
        {:error, e}
    end
  end

  defp insert_activity_with_expiration(data, local, recipients) do
    struct = %Activity{
      data: data,
      local: local,
      actor: data["actor"],
      recipients: recipients
    }

    with {:ok, activity} <- Repo.insert(struct) do
      maybe_create_activity_expiration(activity)
    end
  end

  def notify_and_stream(activity) do
    Notification.create_notifications(activity)

    conversation = create_or_bump_conversation(activity, activity.actor)
    participations = get_participations(conversation)
    stream_out(activity)
    stream_out_participations(participations)
  end

  defp maybe_create_activity_expiration(
         %{data: %{"expires_at" => %DateTime{} = expires_at}} = activity
       ) do
    with {:ok, _job} <-
           Pleroma.Workers.PurgeExpiredActivity.enqueue(%{
             activity_id: activity.id,
             expires_at: expires_at
           }) do
      {:ok, activity}
    end
  end

  defp maybe_create_activity_expiration(activity), do: {:ok, activity}

  defp create_or_bump_conversation(activity, actor) do
    with {:ok, conversation} <- Conversation.create_or_bump_for(activity),
         %User{} = user <- User.get_cached_by_ap_id(actor) do
      Participation.mark_as_read(user, conversation)
      {:ok, conversation}
    end
  end

  defp get_participations({:ok, conversation}) do
    conversation
    |> Repo.preload(:participations, force: true)
    |> Map.get(:participations)
  end

  defp get_participations(_), do: []

  def stream_out_participations(participations) do
    participations =
      participations
      |> Repo.preload(:user)

    Streamer.stream("participation", participations)
  end

  def stream_out_participations(%Object{data: %{"context" => context}}, user) do
    with %Conversation{} = conversation <- Conversation.get_for_ap_id(context) do
      conversation = Repo.preload(conversation, :participations)

      last_activity_id =
        fetch_latest_direct_activity_id_for_context(conversation.ap_id, %{
          user: user,
          blocking_user: user
        })

      if last_activity_id do
        stream_out_participations(conversation.participations)
      end
    end
  end

  def stream_out_participations(_, _), do: :noop

  def stream_out(%Activity{data: %{"type" => data_type}} = activity)
      when data_type in ["Create", "Announce", "Delete"] do
    activity
    |> Topics.get_activity_topics()
    |> Streamer.stream(activity)
  end

  def stream_out(_activity) do
    :noop
  end

  @spec create(map(), boolean()) :: {:ok, Activity.t()} | {:error, any()}
  def create(params, fake \\ false) do
    with {:ok, result} <- Repo.transaction(fn -> do_create(params, fake) end) do
      result
    end
  end

  defp do_create(%{to: to, actor: actor, context: context, object: object} = params, fake) do
    additional = params[:additional] || %{}
    # only accept false as false value
    local = !(params[:local] == false)
    published = params[:published]
    quick_insert? = Config.get([:env]) == :benchmark

    create_data =
      make_create_data(
        %{to: to, actor: actor, published: published, context: context, object: object},
        additional
      )

    with {:ok, activity} <- insert(create_data, local, fake),
         {:fake, false, activity} <- {:fake, fake, activity},
         _ <- increase_replies_count_if_reply(create_data),
         {:quick_insert, false, activity} <- {:quick_insert, quick_insert?, activity},
         {:ok, _actor} <- increase_note_count_if_public(actor, activity),
         _ <- notify_and_stream(activity),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    else
      {:quick_insert, true, activity} ->
        {:ok, activity}

      {:fake, true, activity} ->
        {:ok, activity}

      {:error, message} ->
        Repo.rollback(message)
    end
  end

  @spec listen(map()) :: {:ok, Activity.t()} | {:error, any()}
  def listen(%{to: to, actor: actor, context: context, object: object} = params) do
    additional = params[:additional] || %{}
    # only accept false as false value
    local = !(params[:local] == false)
    published = params[:published]

    listen_data =
      make_listen_data(
        %{to: to, actor: actor, published: published, context: context, object: object},
        additional
      )

    with {:ok, activity} <- insert(listen_data, local),
         _ <- notify_and_stream(activity),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    end
  end

  @spec unfollow(User.t(), User.t(), String.t() | nil, boolean()) ::
          {:ok, Activity.t()} | nil | {:error, any()}
  def unfollow(follower, followed, activity_id \\ nil, local \\ true) do
    with {:ok, result} <-
           Repo.transaction(fn -> do_unfollow(follower, followed, activity_id, local) end) do
      result
    end
  end

  defp do_unfollow(follower, followed, activity_id, local) do
    with %Activity{} = follow_activity <- fetch_latest_follow(follower, followed),
         {:ok, follow_activity} <- update_follow_state(follow_activity, "cancelled"),
         unfollow_data <- make_unfollow_data(follower, followed, follow_activity, activity_id),
         {:ok, activity} <- insert(unfollow_data, local),
         _ <- notify_and_stream(activity),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    else
      nil -> nil
      {:error, error} -> Repo.rollback(error)
    end
  end

  @spec flag(map()) :: {:ok, Activity.t()} | {:error, any()}
  def flag(params) do
    with {:ok, result} <- Repo.transaction(fn -> do_flag(params) end) do
      result
    end
  end

  defp do_flag(
         %{
           actor: actor,
           context: _context,
           account: account,
           statuses: statuses,
           content: content
         } = params
       ) do
    # only accept false as false value
    local = !(params[:local] == false)
    forward = !(params[:forward] == false)

    additional = params[:additional] || %{}

    additional =
      if forward do
        Map.merge(additional, %{"to" => [], "cc" => [account.ap_id]})
      else
        Map.merge(additional, %{"to" => [], "cc" => []})
      end

    with flag_data <- make_flag_data(params, additional),
         {:ok, activity} <- insert(flag_data, local),
         {:ok, stripped_activity} <- strip_report_status_data(activity),
         _ <- notify_and_stream(activity),
         :ok <-
           maybe_federate(stripped_activity) do
      User.all_superusers()
      |> Enum.filter(fn user -> not is_nil(user.email) end)
      |> Enum.each(fn superuser ->
        superuser
        |> Pleroma.Emails.AdminEmail.report(actor, account, statuses, content)
        |> Pleroma.Emails.Mailer.deliver_async()
      end)

      {:ok, activity}
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  @spec move(User.t(), User.t(), boolean()) :: {:ok, Activity.t()} | {:error, any()}
  def move(%User{} = origin, %User{} = target, local \\ true) do
    params = %{
      "type" => "Move",
      "actor" => origin.ap_id,
      "object" => origin.ap_id,
      "target" => target.ap_id
    }

    with true <- origin.ap_id in target.also_known_as,
         {:ok, activity} <- insert(params, local),
         _ <- notify_and_stream(activity) do
      maybe_federate(activity)

      BackgroundWorker.enqueue("move_following", %{
        "origin_id" => origin.id,
        "target_id" => target.id
      })

      {:ok, activity}
    else
      false -> {:error, "Target account must have the origin in `alsoKnownAs`"}
      err -> err
    end
  end

  def fetch_activities_for_context_query(context, opts) do
    public = [Constants.as_public()]

    recipients =
      if opts[:user],
        do: [opts[:user].ap_id | User.following(opts[:user])] ++ public,
        else: public

    from(activity in Activity)
    |> maybe_preload_objects(opts)
    |> maybe_preload_bookmarks(opts)
    |> maybe_set_thread_muted_field(opts)
    |> restrict_blocked(opts)
    |> restrict_recipients(recipients, opts[:user])
    |> restrict_filtered(opts)
    |> where(
      [activity],
      fragment(
        "?->>'type' = ? and ?->>'context' = ?",
        activity.data,
        "Create",
        activity.data,
        ^context
      )
    )
    |> exclude_poll_votes(opts)
    |> exclude_id(opts)
    |> order_by([activity], desc: activity.id)
  end

  @spec fetch_activities_for_context(String.t(), keyword() | map()) :: [Activity.t()]
  def fetch_activities_for_context(context, opts \\ %{}) do
    context
    |> fetch_activities_for_context_query(opts)
    |> Repo.all()
  end

  @spec fetch_latest_direct_activity_id_for_context(String.t(), keyword() | map()) ::
          FlakeId.Ecto.CompatType.t() | nil
  def fetch_latest_direct_activity_id_for_context(context, opts \\ %{}) do
    context
    |> fetch_activities_for_context_query(Map.merge(%{skip_preload: true}, opts))
    |> restrict_visibility(%{visibility: "direct"})
    |> limit(1)
    |> select([a], a.id)
    |> Repo.one()
  end

  @spec fetch_public_or_unlisted_activities(map(), Pagination.type()) :: [Activity.t()]
  def fetch_public_or_unlisted_activities(opts \\ %{}, pagination \\ :keyset) do
    opts = Map.delete(opts, :user)

    [Constants.as_public()]
    |> fetch_activities_query(opts)
    |> restrict_unlisted(opts)
    |> Pagination.fetch_paginated(opts, pagination)
  end

  @spec fetch_public_activities(map(), Pagination.type()) :: [Activity.t()]
  def fetch_public_activities(opts \\ %{}, pagination \\ :keyset) do
    opts
    |> Map.put(:restrict_unlisted, true)
    |> fetch_public_or_unlisted_activities(pagination)
  end

  @valid_visibilities ~w[direct unlisted public private]

  defp restrict_visibility(query, %{visibility: visibility})
       when is_list(visibility) do
    if Enum.all?(visibility, &(&1 in @valid_visibilities)) do
      from(
        a in query,
        where:
          fragment(
            "activity_visibility(?, ?, ?) = ANY (?)",
            a.actor,
            a.recipients,
            a.data,
            ^visibility
          )
      )
    else
      Logger.error("Could not restrict visibility to #{visibility}")
    end
  end

  defp restrict_visibility(query, %{visibility: visibility})
       when visibility in @valid_visibilities do
    from(
      a in query,
      where:
        fragment("activity_visibility(?, ?, ?) = ?", a.actor, a.recipients, a.data, ^visibility)
    )
  end

  defp restrict_visibility(_query, %{visibility: visibility})
       when visibility not in @valid_visibilities do
    Logger.error("Could not restrict visibility to #{visibility}")
  end

  defp restrict_visibility(query, _visibility), do: query

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when is_list(visibility) do
    if Enum.all?(visibility, &(&1 in @valid_visibilities)) do
      from(
        a in query,
        where:
          not fragment(
            "activity_visibility(?, ?, ?) = ANY (?)",
            a.actor,
            a.recipients,
            a.data,
            ^visibility
          )
      )
    else
      Logger.error("Could not exclude visibility to #{visibility}")
      query
    end
  end

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when visibility in @valid_visibilities do
    from(
      a in query,
      where:
        not fragment(
          "activity_visibility(?, ?, ?) = ?",
          a.actor,
          a.recipients,
          a.data,
          ^visibility
        )
    )
  end

  defp exclude_visibility(query, %{exclude_visibilities: visibility})
       when visibility not in [nil | @valid_visibilities] do
    Logger.error("Could not exclude visibility to #{visibility}")
    query
  end

  defp exclude_visibility(query, _visibility), do: query

  defp restrict_thread_visibility(query, _, %{skip_thread_containment: true} = _),
    do: query

  defp restrict_thread_visibility(query, %{user: %User{skip_thread_containment: true}}, _),
    do: query

  defp restrict_thread_visibility(query, %{user: %User{ap_id: ap_id}}, _) do
    from(
      a in query,
      where: fragment("thread_visibility(?, (?)->>'id') = true", ^ap_id, a.data)
    )
  end

  defp restrict_thread_visibility(query, _, _), do: query

  def fetch_user_abstract_activities(user, reading_user, params \\ %{}) do
    params =
      params
      |> Map.put(:user, reading_user)
      |> Map.put(:actor_id, user.ap_id)

    %{
      godmode: params[:godmode],
      reading_user: reading_user
    }
    |> user_activities_recipients()
    |> fetch_activities(params)
    |> Enum.reverse()
  end

  def fetch_user_activities(user, reading_user, params \\ %{}) do
    params =
      params
      |> Map.put(:type, ["Create", "Announce"])
      |> Map.put(:user, reading_user)
      |> Map.put(:actor_id, user.ap_id)
      |> Map.put(:pinned_activity_ids, user.pinned_activities)

    params =
      if User.blocks?(reading_user, user) do
        params
      else
        params
        |> Map.put(:blocking_user, reading_user)
        |> Map.put(:muting_user, reading_user)
      end

    %{
      godmode: params[:godmode],
      reading_user: reading_user
    }
    |> user_activities_recipients()
    |> fetch_activities(params)
    |> Enum.reverse()
  end

  def fetch_statuses(reading_user, params) do
    params = Map.put(params, :type, ["Create", "Announce"])

    %{
      godmode: params[:godmode],
      reading_user: reading_user
    }
    |> user_activities_recipients()
    |> fetch_activities(params, :offset)
    |> Enum.reverse()
  end

  defp user_activities_recipients(%{godmode: true}), do: []

  defp user_activities_recipients(%{reading_user: reading_user}) do
    if reading_user do
      [Constants.as_public(), reading_user.ap_id | User.following(reading_user)]
    else
      [Constants.as_public()]
    end
  end

  defp restrict_announce_object_actor(_query, %{announce_filtering_user: _, skip_preload: true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_announce_object_actor(query, %{announce_filtering_user: %{ap_id: actor}}) do
    from(
      [activity, object] in query,
      where:
        fragment(
          "?->>'type' != ? or ?->>'actor' != ?",
          activity.data,
          "Announce",
          object.data,
          ^actor
        )
    )
  end

  defp restrict_announce_object_actor(query, _), do: query

  defp restrict_since(query, %{since_id: ""}), do: query

  defp restrict_since(query, %{since_id: since_id}) do
    from(activity in query, where: activity.id > ^since_id)
  end

  defp restrict_since(query, _), do: query

  defp restrict_tag_reject(_query, %{tag_reject: _tag_reject, skip_preload: true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_tag_reject(query, %{tag_reject: [_ | _] = tag_reject}) do
    from(
      [_activity, object] in query,
      where: fragment("not (?)->'tag' \\?| (?)", object.data, ^tag_reject)
    )
  end

  defp restrict_tag_reject(query, _), do: query

  defp restrict_tag_all(_query, %{tag_all: _tag_all, skip_preload: true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_tag_all(query, %{tag_all: [_ | _] = tag_all}) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\?& (?)", object.data, ^tag_all)
    )
  end

  defp restrict_tag_all(query, _), do: query

  defp restrict_tag(_query, %{tag: _tag, skip_preload: true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_tag(query, %{tag: tag}) when is_list(tag) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\?| (?)", object.data, ^tag)
    )
  end

  defp restrict_tag(query, %{tag: tag}) when is_binary(tag) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\? (?)", object.data, ^tag)
    )
  end

  defp restrict_tag(query, _), do: query

  defp restrict_recipients(query, [], _user), do: query

  defp restrict_recipients(query, recipients, nil) do
    from(activity in query, where: fragment("? && ?", ^recipients, activity.recipients))
  end

  defp restrict_recipients(query, recipients, user) do
    from(
      activity in query,
      where: fragment("? && ?", ^recipients, activity.recipients),
      or_where: activity.actor == ^user.ap_id
    )
  end

  defp restrict_local(query, %{local_only: true}) do
    from(activity in query, where: activity.local == true)
  end

  defp restrict_local(query, _), do: query

  defp restrict_actor(query, %{actor_id: actor_id}) do
    from(activity in query, where: activity.actor == ^actor_id)
  end

  defp restrict_actor(query, _), do: query

  defp restrict_type(query, %{type: type}) when is_binary(type) do
    from(activity in query, where: fragment("?->>'type' = ?", activity.data, ^type))
  end

  defp restrict_type(query, %{type: type}) do
    from(activity in query, where: fragment("?->>'type' = ANY(?)", activity.data, ^type))
  end

  defp restrict_type(query, _), do: query

  defp restrict_state(query, %{state: state}) do
    from(activity in query, where: fragment("?->>'state' = ?", activity.data, ^state))
  end

  defp restrict_state(query, _), do: query

  defp restrict_favorited_by(query, %{favorited_by: ap_id}) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'likes' \\? (?)", object.data, ^ap_id)
    )
  end

  defp restrict_favorited_by(query, _), do: query

  defp restrict_media(_query, %{only_media: _val, skip_preload: true}) do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_media(query, %{only_media: true}) do
    from(
      [activity, object] in query,
      where: fragment("(?)->>'type' = ?", activity.data, "Create"),
      where: fragment("not (?)->'attachment' = (?)", object.data, ^[])
    )
  end

  defp restrict_media(query, _), do: query

  defp restrict_replies(query, %{exclude_replies: true}) do
    from(
      [_activity, object] in query,
      where: fragment("?->>'inReplyTo' is null", object.data)
    )
  end

  defp restrict_replies(query, %{
         reply_filtering_user: %User{} = user,
         reply_visibility: "self"
       }) do
    from(
      [activity, object] in query,
      where:
        fragment(
          "?->>'inReplyTo' is null OR ? = ANY(?)",
          object.data,
          ^user.ap_id,
          activity.recipients
        )
    )
  end

  defp restrict_replies(query, %{
         reply_filtering_user: %User{} = user,
         reply_visibility: "following"
       }) do
    from(
      [activity, object] in query,
      where:
        fragment(
          """
          ?->>'type' != 'Create'     -- This isn't a Create
          OR ?->>'inReplyTo' is null -- this isn't a reply
          OR ? && array_remove(?, ?) -- The recipient is us or one of our friends,
                                     -- unless they are the author (because authors
                                     -- are also part of the recipients). This leads
                                     -- to a bug that self-replies by friends won't
                                     -- show up.
          OR ? = ?                   -- The actor is us
          """,
          activity.data,
          object.data,
          ^[user.ap_id | User.get_cached_user_friends_ap_ids(user)],
          activity.recipients,
          activity.actor,
          activity.actor,
          ^user.ap_id
        )
    )
  end

  defp restrict_replies(query, _), do: query

  defp restrict_reblogs(query, %{exclude_reblogs: true}) do
    from(activity in query, where: fragment("?->>'type' != 'Announce'", activity.data))
  end

  defp restrict_reblogs(query, _), do: query

  defp restrict_muted(query, %{with_muted: true}), do: query

  defp restrict_muted(query, %{muting_user: %User{} = user} = opts) do
    mutes = opts[:muted_users_ap_ids] || User.muted_users_ap_ids(user)

    query =
      from([activity] in query,
        where: fragment("not (? = ANY(?))", activity.actor, ^mutes),
        where: fragment("not (?->'to' \\?| ?)", activity.data, ^mutes)
      )

    unless opts[:skip_preload] do
      from([thread_mute: tm] in query, where: is_nil(tm.user_id))
    else
      query
    end
  end

  defp restrict_muted(query, _), do: query

  defp restrict_blocked(query, %{blocking_user: %User{} = user} = opts) do
    blocked_ap_ids = opts[:blocked_users_ap_ids] || User.blocked_users_ap_ids(user)
    domain_blocks = user.domain_blocks || []

    following_ap_ids = User.get_friends_ap_ids(user)

    query =
      if has_named_binding?(query, :object), do: query, else: Activity.with_joined_object(query)

    from(
      [activity, object: o] in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^blocked_ap_ids),
      where:
        fragment(
          "((not (? && ?)) or ? = ?)",
          activity.recipients,
          ^blocked_ap_ids,
          activity.actor,
          ^user.ap_id
        ),
      where:
        fragment(
          "recipients_contain_blocked_domains(?, ?) = false",
          activity.recipients,
          ^domain_blocks
        ),
      where:
        fragment(
          "not (?->>'type' = 'Announce' and ?->'to' \\?| ?)",
          activity.data,
          activity.data,
          ^blocked_ap_ids
        ),
      where:
        fragment(
          "(not (split_part(?, '/', 3) = ANY(?))) or ? = ANY(?)",
          activity.actor,
          ^domain_blocks,
          activity.actor,
          ^following_ap_ids
        ),
      where:
        fragment(
          "(not (split_part(?->>'actor', '/', 3) = ANY(?))) or (?->>'actor') = ANY(?)",
          o.data,
          ^domain_blocks,
          o.data,
          ^following_ap_ids
        )
    )
  end

  defp restrict_blocked(query, _), do: query

  defp restrict_unlisted(query, %{restrict_unlisted: true}) do
    from(
      activity in query,
      where:
        fragment(
          "not (coalesce(?->'cc', '{}'::jsonb) \\?| ?)",
          activity.data,
          ^[Constants.as_public()]
        )
    )
  end

  defp restrict_unlisted(query, _), do: query

  defp restrict_pinned(query, %{pinned: true, pinned_activity_ids: ids}) do
    from(activity in query, where: activity.id in ^ids)
  end

  defp restrict_pinned(query, _), do: query

  defp restrict_muted_reblogs(query, %{muting_user: %User{} = user} = opts) do
    muted_reblogs = opts[:reblog_muted_users_ap_ids] || User.reblog_muted_users_ap_ids(user)

    from(
      activity in query,
      where:
        fragment(
          "not ( ?->>'type' = 'Announce' and ? = ANY(?))",
          activity.data,
          activity.actor,
          ^muted_reblogs
        )
    )
  end

  defp restrict_muted_reblogs(query, _), do: query

  defp restrict_instance(query, %{instance: instance}) do
    users =
      from(
        u in User,
        select: u.ap_id,
        where: fragment("? LIKE ?", u.nickname, ^"%@#{instance}")
      )
      |> Repo.all()

    from(activity in query, where: activity.actor in ^users)
  end

  defp restrict_instance(query, _), do: query

  defp restrict_filtered(query, %{user: %User{} = user}) do
    case Filter.compose_regex(user) do
      nil ->
        query

      regex ->
        from([activity, object] in query,
          where:
            fragment("not(?->>'content' ~* ?)", object.data, ^regex) or
              activity.actor == ^user.ap_id
        )
    end
  end

  defp restrict_filtered(query, %{blocking_user: %User{} = user}) do
    restrict_filtered(query, %{user: user})
  end

  defp restrict_filtered(query, _), do: query

  defp exclude_poll_votes(query, %{include_poll_votes: true}), do: query

  defp exclude_poll_votes(query, _) do
    if has_named_binding?(query, :object) do
      from([activity, object: o] in query,
        where: fragment("not(?->>'type' = ?)", o.data, "Answer")
      )
    else
      query
    end
  end

  defp exclude_chat_messages(query, %{include_chat_messages: true}), do: query

  defp exclude_chat_messages(query, _) do
    if has_named_binding?(query, :object) do
      from([activity, object: o] in query,
        where: fragment("not(?->>'type' = ?)", o.data, "ChatMessage")
      )
    else
      query
    end
  end

  defp exclude_invisible_actors(query, %{invisible_actors: true}), do: query

  defp exclude_invisible_actors(query, _opts) do
    invisible_ap_ids =
      User.Query.build(%{invisible: true, select: [:ap_id]})
      |> Repo.all()
      |> Enum.map(fn %{ap_id: ap_id} -> ap_id end)

    from([activity] in query, where: activity.actor not in ^invisible_ap_ids)
  end

  defp exclude_id(query, %{exclude_id: id}) when is_binary(id) do
    from(activity in query, where: activity.id != ^id)
  end

  defp exclude_id(query, _), do: query

  defp maybe_preload_objects(query, %{skip_preload: true}), do: query

  defp maybe_preload_objects(query, _) do
    query
    |> Activity.with_preloaded_object()
  end

  defp maybe_preload_bookmarks(query, %{skip_preload: true}), do: query

  defp maybe_preload_bookmarks(query, opts) do
    query
    |> Activity.with_preloaded_bookmark(opts[:user])
  end

  defp maybe_preload_report_notes(query, %{preload_report_notes: true}) do
    query
    |> Activity.with_preloaded_report_notes()
  end

  defp maybe_preload_report_notes(query, _), do: query

  defp maybe_set_thread_muted_field(query, %{skip_preload: true}), do: query

  defp maybe_set_thread_muted_field(query, opts) do
    query
    |> Activity.with_set_thread_muted_field(opts[:muting_user] || opts[:user])
  end

  defp maybe_order(query, %{order: :desc}) do
    query
    |> order_by(desc: :id)
  end

  defp maybe_order(query, %{order: :asc}) do
    query
    |> order_by(asc: :id)
  end

  defp maybe_order(query, _), do: query

  defp fetch_activities_query_ap_ids_ops(opts) do
    source_user = opts[:muting_user]
    ap_id_relationships = if source_user, do: [:mute, :reblog_mute], else: []

    ap_id_relationships =
      if opts[:blocking_user] && opts[:blocking_user] == source_user do
        [:block | ap_id_relationships]
      else
        ap_id_relationships
      end

    preloaded_ap_ids = User.outgoing_relationships_ap_ids(source_user, ap_id_relationships)

    restrict_blocked_opts = Map.merge(%{blocked_users_ap_ids: preloaded_ap_ids[:block]}, opts)
    restrict_muted_opts = Map.merge(%{muted_users_ap_ids: preloaded_ap_ids[:mute]}, opts)

    restrict_muted_reblogs_opts =
      Map.merge(%{reblog_muted_users_ap_ids: preloaded_ap_ids[:reblog_mute]}, opts)

    {restrict_blocked_opts, restrict_muted_opts, restrict_muted_reblogs_opts}
  end

  def fetch_activities_query(recipients, opts \\ %{}) do
    {restrict_blocked_opts, restrict_muted_opts, restrict_muted_reblogs_opts} =
      fetch_activities_query_ap_ids_ops(opts)

    config = %{
      skip_thread_containment: Config.get([:instance, :skip_thread_containment])
    }

    Activity
    |> maybe_preload_objects(opts)
    |> maybe_preload_bookmarks(opts)
    |> maybe_preload_report_notes(opts)
    |> maybe_set_thread_muted_field(opts)
    |> maybe_order(opts)
    |> restrict_recipients(recipients, opts[:user])
    |> restrict_replies(opts)
    |> restrict_tag(opts)
    |> restrict_tag_reject(opts)
    |> restrict_tag_all(opts)
    |> restrict_since(opts)
    |> restrict_local(opts)
    |> restrict_actor(opts)
    |> restrict_type(opts)
    |> restrict_state(opts)
    |> restrict_favorited_by(opts)
    |> restrict_blocked(restrict_blocked_opts)
    |> restrict_muted(restrict_muted_opts)
    |> restrict_filtered(opts)
    |> restrict_media(opts)
    |> restrict_visibility(opts)
    |> restrict_thread_visibility(opts, config)
    |> restrict_reblogs(opts)
    |> restrict_pinned(opts)
    |> restrict_muted_reblogs(restrict_muted_reblogs_opts)
    |> restrict_instance(opts)
    |> restrict_announce_object_actor(opts)
    |> restrict_filtered(opts)
    |> Activity.restrict_deactivated_users()
    |> exclude_poll_votes(opts)
    |> exclude_chat_messages(opts)
    |> exclude_invisible_actors(opts)
    |> exclude_visibility(opts)
  end

  def fetch_activities(recipients, opts \\ %{}, pagination \\ :keyset) do
    list_memberships = Pleroma.List.memberships(opts[:user])

    fetch_activities_query(recipients ++ list_memberships, opts)
    |> Pagination.fetch_paginated(opts, pagination)
    |> Enum.reverse()
    |> maybe_update_cc(list_memberships, opts[:user])
  end

  @doc """
  Fetch favorites activities of user with order by sort adds to favorites
  """
  @spec fetch_favourites(User.t(), map(), Pagination.type()) :: list(Activity.t())
  def fetch_favourites(user, params \\ %{}, pagination \\ :keyset) do
    user.ap_id
    |> Activity.Queries.by_actor()
    |> Activity.Queries.by_type("Like")
    |> Activity.with_joined_object()
    |> Object.with_joined_activity()
    |> select([like, object, activity], %{activity | object: object, pagination_id: like.id})
    |> order_by([like, _, _], desc_nulls_last: like.id)
    |> Pagination.fetch_paginated(
      Map.merge(params, %{skip_order: true}),
      pagination
    )
  end

  defp maybe_update_cc(activities, [_ | _] = list_memberships, %User{ap_id: user_ap_id}) do
    Enum.map(activities, fn
      %{data: %{"bcc" => [_ | _] = bcc}} = activity ->
        if Enum.any?(bcc, &(&1 in list_memberships)) do
          update_in(activity.data["cc"], &[user_ap_id | &1])
        else
          activity
        end

      activity ->
        activity
    end)
  end

  defp maybe_update_cc(activities, _, _), do: activities

  defp fetch_activities_bounded_query(query, recipients, recipients_with_public) do
    from(activity in query,
      where:
        fragment("? && ?", activity.recipients, ^recipients) or
          (fragment("? && ?", activity.recipients, ^recipients_with_public) and
             ^Constants.as_public() in activity.recipients)
    )
  end

  def fetch_activities_bounded(
        recipients,
        recipients_with_public,
        opts \\ %{},
        pagination \\ :keyset
      ) do
    fetch_activities_query([], opts)
    |> fetch_activities_bounded_query(recipients, recipients_with_public)
    |> Pagination.fetch_paginated(opts, pagination)
    |> Enum.reverse()
  end

  @spec upload(Upload.source(), keyword()) :: {:ok, Object.t()} | {:error, any()}
  def upload(file, opts \\ []) do
    with {:ok, data} <- Upload.store(file, opts) do
      obj_data = Maps.put_if_present(data, "actor", opts[:actor])

      Repo.insert(%Object{data: obj_data})
    end
  end

  @spec get_actor_url(any()) :: binary() | nil
  defp get_actor_url(url) when is_binary(url), do: url
  defp get_actor_url(%{"href" => href}) when is_binary(href), do: href

  defp get_actor_url(url) when is_list(url) do
    url
    |> List.first()
    |> get_actor_url()
  end

  defp get_actor_url(_url), do: nil

  defp object_to_user_data(data) do
    avatar =
      data["icon"]["url"] &&
        %{
          "type" => "Image",
          "url" => [%{"href" => data["icon"]["url"]}]
        }

    banner =
      data["image"]["url"] &&
        %{
          "type" => "Image",
          "url" => [%{"href" => data["image"]["url"]}]
        }

    fields =
      data
      |> Map.get("attachment", [])
      |> Enum.filter(fn %{"type" => t} -> t == "PropertyValue" end)
      |> Enum.map(fn fields -> Map.take(fields, ["name", "value"]) end)

    emojis =
      data
      |> Map.get("tag", [])
      |> Enum.filter(fn
        %{"type" => "Emoji"} -> true
        _ -> false
      end)
      |> Map.new(fn %{"icon" => %{"url" => url}, "name" => name} ->
        {String.trim(name, ":"), url}
      end)

    is_locked = data["manuallyApprovesFollowers"] || false
    capabilities = data["capabilities"] || %{}
    accepts_chat_messages = capabilities["acceptsChatMessages"]
    data = Transmogrifier.maybe_fix_user_object(data)
    discoverable = data["discoverable"] || false
    invisible = data["invisible"] || false
    actor_type = data["type"] || "Person"

    public_key =
      if is_map(data["publicKey"]) && is_binary(data["publicKey"]["publicKeyPem"]) do
        data["publicKey"]["publicKeyPem"]
      else
        nil
      end

    shared_inbox =
      if is_map(data["endpoints"]) && is_binary(data["endpoints"]["sharedInbox"]) do
        data["endpoints"]["sharedInbox"]
      else
        nil
      end

    user_data = %{
      ap_id: data["id"],
      uri: get_actor_url(data["url"]),
      ap_enabled: true,
      banner: banner,
      fields: fields,
      emoji: emojis,
      is_locked: is_locked,
      discoverable: discoverable,
      invisible: invisible,
      avatar: avatar,
      name: data["name"],
      follower_address: data["followers"],
      following_address: data["following"],
      bio: data["summary"] || "",
      actor_type: actor_type,
      also_known_as: Map.get(data, "alsoKnownAs", []),
      public_key: public_key,
      inbox: data["inbox"],
      shared_inbox: shared_inbox,
      accepts_chat_messages: accepts_chat_messages
    }

    # nickname can be nil because of virtual actors
    if data["preferredUsername"] do
      Map.put(
        user_data,
        :nickname,
        "#{data["preferredUsername"]}@#{URI.parse(data["id"]).host}"
      )
    else
      Map.put(user_data, :nickname, nil)
    end
  end

  def fetch_follow_information_for_user(user) do
    with {:ok, following_data} <-
           Fetcher.fetch_and_contain_remote_object_from_id(user.following_address,
             force_http: true
           ),
         {:ok, hide_follows} <- collection_private(following_data),
         {:ok, followers_data} <-
           Fetcher.fetch_and_contain_remote_object_from_id(user.follower_address, force_http: true),
         {:ok, hide_followers} <- collection_private(followers_data) do
      {:ok,
       %{
         hide_follows: hide_follows,
         follower_count: normalize_counter(followers_data["totalItems"]),
         following_count: normalize_counter(following_data["totalItems"]),
         hide_followers: hide_followers
       }}
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  defp normalize_counter(counter) when is_integer(counter), do: counter
  defp normalize_counter(_), do: 0

  def maybe_update_follow_information(user_data) do
    with {:enabled, true} <- {:enabled, Config.get([:instance, :external_user_synchronization])},
         {_, true} <- {:user_type_check, user_data[:type] in ["Person", "Service"]},
         {_, true} <-
           {:collections_available,
            !!(user_data[:following_address] && user_data[:follower_address])},
         {:ok, info} <-
           fetch_follow_information_for_user(user_data) do
      info = Map.merge(user_data[:info] || %{}, info)

      user_data
      |> Map.put(:info, info)
    else
      {:user_type_check, false} ->
        user_data

      {:collections_available, false} ->
        user_data

      {:enabled, false} ->
        user_data

      e ->
        Logger.error(
          "Follower/Following counter update for #{user_data.ap_id} failed.\n" <> inspect(e)
        )

        user_data
    end
  end

  defp collection_private(%{"first" => %{"type" => type}})
       when type in ["CollectionPage", "OrderedCollectionPage"],
       do: {:ok, false}

  defp collection_private(%{"first" => first}) do
    with {:ok, %{"type" => type}} when type in ["CollectionPage", "OrderedCollectionPage"] <-
           Fetcher.fetch_and_contain_remote_object_from_id(first) do
      {:ok, false}
    else
      {:error, {:ok, %{status: code}}} when code in [401, 403] -> {:ok, true}
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  defp collection_private(_data), do: {:ok, true}

  def user_data_from_user_object(data) do
    with {:ok, data} <- MRF.filter(data) do
      {:ok, object_to_user_data(data)}
    else
      e -> {:error, e}
    end
  end

  def fetch_and_prepare_user_from_ap_id(ap_id, opts \\ []) do
    with {:ok, data} <- Fetcher.fetch_and_contain_remote_object_from_id(ap_id, opts),
         {:ok, data} <- user_data_from_user_object(data) do
      {:ok, maybe_update_follow_information(data)}
    else
      # If this has been deleted, only log a debug and not an error
      {:error, "Object has been deleted" = e} ->
        Logger.debug("Could not decode user at fetch #{ap_id}, #{inspect(e)}")
        {:error, e}

      {:error, {:reject, reason} = e} ->
        Logger.info("Rejected user #{ap_id}: #{inspect(reason)}")
        {:error, e}

      {:error, e} ->
        Logger.error("Could not decode user at fetch #{ap_id}, #{inspect(e)}")
        {:error, e}
    end
  end

  def maybe_handle_clashing_nickname(data) do
    with nickname when is_binary(nickname) <- data[:nickname],
         %User{} = old_user <- User.get_by_nickname(nickname),
         {_, false} <- {:ap_id_comparison, data[:ap_id] == old_user.ap_id} do
      Logger.info(
        "Found an old user for #{nickname}, the old ap id is #{old_user.ap_id}, new one is #{
          data[:ap_id]
        }, renaming."
      )

      old_user
      |> User.remote_user_changeset(%{nickname: "#{old_user.id}.#{old_user.nickname}"})
      |> User.update_and_set_cache()
    else
      {:ap_id_comparison, true} ->
        Logger.info(
          "Found an old user for #{data[:nickname]}, but the ap id #{data[:ap_id]} is the same as the new user. Race condition? Not changing anything."
        )

      _ ->
        nil
    end
  end

  def make_user_from_ap_id(ap_id, opts \\ []) do
    user = User.get_cached_by_ap_id(ap_id)

    if user && !User.ap_enabled?(user) do
      Transmogrifier.upgrade_user_from_ap_id(ap_id)
    else
      with {:ok, data} <- fetch_and_prepare_user_from_ap_id(ap_id, opts) do
        if user do
          user
          |> User.remote_user_changeset(data)
          |> User.update_and_set_cache()
        else
          maybe_handle_clashing_nickname(data)

          data
          |> User.remote_user_changeset()
          |> Repo.insert()
          |> User.set_cache()
        end
      end
    end
  end

  def make_user_from_nickname(nickname) do
    with {:ok, %{"ap_id" => ap_id}} when not is_nil(ap_id) <- WebFinger.finger(nickname) do
      make_user_from_ap_id(ap_id)
    else
      _e -> {:error, "No AP id in WebFinger"}
    end
  end

  # filter out broken threads
  defp contain_broken_threads(%Activity{} = activity, %User{} = user) do
    entire_thread_visible_for_user?(activity, user)
  end

  # do post-processing on a specific activity
  def contain_activity(%Activity{} = activity, %User{} = user) do
    contain_broken_threads(activity, user)
  end

  def fetch_direct_messages_query do
    Activity
    |> restrict_type(%{type: "Create"})
    |> restrict_visibility(%{visibility: "direct"})
    |> order_by([activity], asc: activity.id)
  end
end
