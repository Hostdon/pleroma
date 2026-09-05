# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPub do
  alias Pleroma.Activity
  alias Pleroma.Activity.Ir.Topics
  alias Pleroma.Config
  alias Pleroma.Constants
  alias Pleroma.Conversation
  alias Pleroma.Conversation.Participation
  alias Pleroma.Filter
  alias Pleroma.Hashtag
  alias Pleroma.Maps
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.Upload
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.Streamer
  alias Pleroma.Workers.BackgroundWorker
  alias Pleroma.Workers.PollWorker

  import Ecto.Query
  import Pleroma.Web.ActivityPub.Utils
  import Pleroma.Web.ActivityPub.Visibility

  require Logger
  require Pleroma.Constants

  @behaviour Pleroma.Web.ActivityPub.ActivityPub.Persisting
  @behaviour Pleroma.Web.ActivityPub.ActivityPub.Streaming

  defp get_recipients(%{"type" => "Create"} = data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    actor = Map.get(data, "actor", nil)
    recipients = [to, cc, bcc, [actor]] |> Enum.concat() |> Enum.filter(& &1) |> Enum.uniq()
    {recipients, to, cc}
  end

  defp get_recipients(data) do
    to = Map.get(data, "to", [])
    cc = Map.get(data, "cc", [])
    bcc = Map.get(data, "bcc", [])
    recipients = Enum.concat([to, cc, bcc])
    {recipients, to, cc}
  end

  defp check_actor_can_insert(%{"type" => "Delete"}), do: true
  defp check_actor_can_insert(%{"type" => "Undo"}), do: true

  defp check_actor_can_insert(%{"actor" => actor}) when is_binary(actor) do
    case User.get_cached_by_ap_id(actor) do
      %User{is_active: true} -> true
      _ -> false
    end
  end

  defp check_actor_can_insert(_), do: true

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

  def update_last_status_at_if_public(actor, object) do
    if is_public?(object), do: User.update_last_status_at(actor), else: {:ok, actor}
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

  @object_types ~w[Question Answer Audio Video Event Article Note Page]
  @impl true
  def persist(%{"type" => type} = object, meta) when type in @object_types do
    with {:ok, object} <- Object.create(object) do
      {:ok, object, meta}
    end
  end

  @unpersisted_activity_types ~w[Undo Delete Remove Accept Reject]
  @impl true
  def persist(%{"type" => type} = object, [local: false] = meta)
      when type in @unpersisted_activity_types do
    {:ok, object, meta}
    {recipients, _, _} = get_recipients(object)

    unpersisted = %Activity{
      data: object,
      local: false,
      recipients: recipients,
      actor: object["actor"]
    }

    {:ok, unpersisted, meta}
  end

  @impl true
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
         {_, true} <- {:actor_check, bypass_actor_check || check_actor_can_insert(map)},
         {_, true} <- {:remote_limit_pass, check_remote_limit(map)},
         {:ok, map} <- MRF.filter(map),
         {recipients, _, _} = get_recipients(map),
         {:fake, false, map, recipients} <- {:fake, fake, map, recipients},
         {:containment, :ok} <- {:containment, Containment.contain_child(map)},
         {:ok, map, object} <- insert_full_object(map),
         {:ok, activity} <- insert_activity_with_expiration(map, local, recipients) do
      # Splice in the child object if we have one.
      activity = Maps.put_if_present(activity, :object, object)

      Pleroma.Web.RichMedia.Card.get_by_activity(activity)

      # Add local posts to search index
      if local, do: Pleroma.Search.add_to_index(activity)

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

        Pleroma.Web.RichMedia.Card.get_by_activity(activity)
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
    # XXX: all callers of this should be moved to side_effect handling, such that
    # notifications can be collected and only be sent out _after_ the transaction succeed
    {:ok, notifications, _} = Notification.create_notifications(activity)
    Notification.send(notifications)
    stream_out(activity)
  end

  defp maybe_bump_conversation(activity) do
    if Visibility.is_direct?(activity) do
      conversation = create_or_bump_conversation(activity, activity.actor)
      participations = get_participations(conversation)
      stream_out_participations(participations)
    end
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

  def create_or_bump_conversation(activity, actor) do
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
      |> Repo.preload([:user, :conversation])

    Streamer.stream("participation", participations)
  end

  @impl true
  def stream_out_participations(%Object{data: %{"context" => context}}, user) do
    with %Conversation{} = conversation <- Conversation.get_for_ap_id(context) do
      conversation = Repo.preload(conversation, :participations)

      last_activity_id =
        fetch_latest_direct_activity_id_for_context(conversation.ap_id, user)

      if last_activity_id do
        stream_out_participations(conversation.participations)
      end
    end
  end

  @impl true
  def stream_out_participations(_, _), do: :noop

  @impl true
  def stream_out(%Activity{data: %{"type" => data_type}} = activity)
      when data_type in ["Create", "Announce", "Delete", "Update"] do
    activity
    |> Topics.get_activity_topics()
    |> Streamer.stream(activity)
  end

  @impl true
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
         {:ok, _actor} <- update_last_status_at_if_public(actor, activity),
         _ <- notify_and_stream(activity),
         _ <- maybe_bump_conversation(activity),
         :ok <- maybe_schedule_poll_notifications(activity),
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

  defp maybe_schedule_poll_notifications(activity) do
    PollWorker.schedule_poll_end(activity)
    :ok
  end

  @spec unfollow(User.t(), User.t(), String.t() | nil, boolean()) ::
          {:ok, Activity.t()} | nil | {:error, any()}
  def unfollow(follower, followed, activity_id \\ nil, local \\ true) do
    with {:ok, result} <-
           Repo.transaction(fn -> do_unfollow(follower, followed, activity_id, local) end) do
      result
    end
  end

  defp do_unfollow(follower, followed, activity_id, local)

  defp do_unfollow(follower, followed, activity_id, local) when local == true do
    with %Activity{} = follow_activity <- fetch_latest_follow(follower, followed),
         unfollow_data <- make_unfollow_data(follower, followed, follow_activity, activity_id),
         {:ok, activity} <- insert(unfollow_data, local),
         {:ok, _activity} <- Repo.delete(follow_activity),
         _ <- notify_and_stream(activity),
         :ok <- maybe_federate(activity) do
      {:ok, activity}
    else
      nil -> nil
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp do_unfollow(follower, followed, activity_id, false) do
    # On a remote unfollow, _remove_ their activity from the database, since some software (MISSKEEEEY)
    # uses deterministic ids for follows.
    with %Activity{} = follow_activity <- fetch_latest_follow(follower, followed),
         {:ok, _activity} <- Repo.delete(follow_activity),
         unfollow_data <- make_unfollow_data(follower, followed, follow_activity, activity_id),
         unfollow_activity <- make_unfollow_activity(unfollow_data, false),
         _ <- notify_and_stream(unfollow_activity) do
      {:ok, unfollow_activity}
    else
      nil -> nil
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp make_unfollow_activity(data, local) do
    {recipients, _, _} = get_recipients(data)

    %Activity{
      data: data,
      local: local,
      actor: data["actor"],
      recipients: recipients
    }
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
      |> Enum.filter(fn user -> user.ap_id != actor end)
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
      "target" => target.ap_id,
      "to" => [origin.follower_address]
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
    public = Constants.as_public()
    user = opts[:user]

    recipients =
      cond do
        opts[:custom_recipients] != nil ->
          opts[:custom_recipients]

        user && user.local ->
          [public, as_local_public(), opts[:user].ap_id | User.following(opts[:user])]

        user != nil ->
          [public, opts[:user].ap_id | User.following(opts[:user])]

        true ->
          [public]
      end

    from(activity in Activity)
    |> maybe_preload_objects(opts)
    |> maybe_preload_bookmarks(opts)
    |> restrict_blocked(opts)
    |> restrict_blockers_visibility(opts)
    |> restrict_muted_users(opts)
    |> restrict_recipients(recipients, user)
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

  def fetch_objects_for_replies_collection(parent_ap_id, opts \\ %{}) do
    opts =
      opts
      |> Map.put(:order_asc, true)
      |> Map.put(:id_type, :integer)

    from(o in Object,
      where:
        fragment("?->>'inReplyTo' = ?", o.data, ^parent_ap_id) and
          fragment(
            "(?->'to' \\? ?::text OR ?->'cc' \\? ?::text)",
            o.data,
            ^Pleroma.Constants.as_public(),
            o.data,
            ^Pleroma.Constants.as_public()
          ) and
          fragment("?->>'type' <> 'Answer'", o.data),
      select: %{id: o.id, ap_id: fragment("?->>'id'", o.data)}
    )
    |> Pagination.fetch_paginated(opts, :keyset)
  end

  @spec fetch_latest_direct_activity_id_for_context(String.t(), User.t()) ::
          FlakeId.Ecto.CompatType.t() | nil
  def fetch_latest_direct_activity_id_for_context(context, user) do
    opts = %{
      skip_preload: true,
      user: user,
      blocking_user: user,
      # only want directly addressed activities
      custom_recipients: [user.ap_id]
    }

    # to filter out non-direct mentions other than follower-only
    nodm_scope = [Constants.as_public(), as_local_public()]

    context
    |> fetch_activities_for_context_query(opts)
    # filter out publicly visible and local-only posts
    |> where([a], fragment("NOT (? && ?)", a.recipients, ^nodm_scope))
    # filter out followers-only
    |> join(:inner, [a], u in User, as: :actor_user, on: a.actor == u.ap_id)
    |> where([a, actor_user: u], u.follower_address not in a.recipients)
    |> limit(1)
    |> select([a], a.id)
    |> Repo.one()
  end

  defp fetch_paginated_optimized(query, opts, pagination) do
    # Note: tag-filtering funcs may apply "ORDER BY objects.id DESC",
    #   and extra sorting on "activities.id DESC NULLS LAST" would worse the query plan
    opts = Map.put(opts, :skip_extra_order, true)

    Pagination.fetch_paginated(query, opts, pagination)
  end

  def fetch_activities(recipients, opts \\ %{}, pagination \\ :keyset) do
    fetch_activities_query(recipients, opts)
    |> fetch_paginated_optimized(opts, pagination)
    |> Enum.reverse()
  end

  @spec fetch_public_or_unlisted_activities(map(), Pagination.type()) :: [Activity.t()]
  def fetch_public_or_unlisted_activities(opts \\ %{}, pagination \\ :keyset) do
    includes_local_public = Map.get(opts, :includes_local_public, false)

    opts = Map.delete(opts, :user)

    intended_recipients =
      if includes_local_public do
        [Constants.as_public(), as_local_public()]
      else
        [Constants.as_public()]
      end

    intended_recipients
    |> fetch_activities_query(opts)
    |> restrict_unlisted(opts)
    |> fetch_paginated_optimized(opts, pagination)
  end

  @spec fetch_public_activities(map(), Pagination.type()) :: [Activity.t()]
  def fetch_public_activities(opts \\ %{}, pagination \\ :keyset) do
    opts
    |> Map.put(:restrict_unlisted, true)
    |> fetch_public_or_unlisted_activities(pagination)
  end

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

  def fetch_user_activities(user, reading_user, params \\ %{})

  def fetch_user_activities(user, reading_user, %{total: true} = params) do
    result = fetch_activities_for_user(user, reading_user, params)

    Keyword.put(result, :items, Enum.reverse(result[:items]))
  end

  def fetch_user_activities(user, reading_user, params) do
    user
    |> fetch_activities_for_user(reading_user, params)
    |> Enum.reverse()
  end

  defp fetch_activities_for_user(user, reading_user, params) do
    params =
      params
      |> Map.put(:type, ["Create", "Announce"])
      |> Map.put(:user, reading_user)
      |> Map.put(:actor_id, user.ap_id)
      |> Map.put(:pinned_object_ids, Map.keys(user.pinned_objects))

    params =
      if User.blocks?(reading_user, user) do
        params
      else
        params
        |> Map.put(:blocking_user, reading_user)
        |> Map.put(:muting_user, reading_user)
      end

    pagination_type = Map.get(params, :pagination_type) || :keyset

    %{
      godmode: params[:godmode],
      reading_user: reading_user
    }
    |> user_activities_recipients()
    |> fetch_activities(params, pagination_type)
  end

  def fetch_statuses(reading_user, %{total: true} = params) do
    result = fetch_activities_for_reading_user(reading_user, params)
    Keyword.put(result, :items, Enum.reverse(result[:items]))
  end

  def fetch_statuses(reading_user, params) do
    reading_user
    |> fetch_activities_for_reading_user(params)
    |> Enum.reverse()
  end

  defp fetch_activities_for_reading_user(reading_user, params) do
    params = Map.put(params, :type, ["Create", "Announce"])

    %{
      godmode: params[:godmode],
      reading_user: reading_user
    }
    |> user_activities_recipients()
    |> fetch_activities(params, :offset)
  end

  def user_activities_recipients(%{godmode: true}), do: []

  def user_activities_recipients(%{reading_user: reading_user}) do
    if not is_nil(reading_user) and reading_user.local do
      [
        Constants.as_public(),
        as_local_public(),
        reading_user.ap_id | User.following(reading_user)
      ]
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

  defp restrict_embedded_tag_all(_query, %{tag_all: _tag_all, skip_preload: true}) do
    raise_on_missing_preload()
  end

  defp restrict_embedded_tag_all(query, %{tag_all: [_ | _] = tag_all}) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\?& (?)", object.data, ^tag_all)
    )
  end

  defp restrict_embedded_tag_all(query, %{tag_all: tag}) when is_binary(tag) do
    restrict_embedded_tag_any(query, %{tag: tag})
  end

  defp restrict_embedded_tag_all(query, _), do: query

  defp restrict_embedded_tag_any(_query, %{tag: _tag, skip_preload: true}) do
    raise_on_missing_preload()
  end

  defp restrict_embedded_tag_any(query, %{tag: [_ | _] = tag_any}) do
    from(
      [_activity, object] in query,
      where: fragment("(?)->'tag' \\?| (?)", object.data, ^tag_any)
    )
  end

  defp restrict_embedded_tag_any(query, %{tag: tag}) when is_binary(tag) do
    restrict_embedded_tag_any(query, %{tag: [tag]})
  end

  defp restrict_embedded_tag_any(query, _), do: query

  defp restrict_embedded_tag_reject_any(_query, %{tag_reject: _tag_reject, skip_preload: true}) do
    raise_on_missing_preload()
  end

  defp restrict_embedded_tag_reject_any(query, %{tag_reject: [_ | _] = tag_reject}) do
    from(
      [_activity, object] in query,
      where: fragment("not (?)->'tag' \\?| (?)", object.data, ^tag_reject)
    )
  end

  defp restrict_embedded_tag_reject_any(query, %{tag_reject: tag_reject})
       when is_binary(tag_reject) do
    restrict_embedded_tag_reject_any(query, %{tag_reject: [tag_reject]})
  end

  defp restrict_embedded_tag_reject_any(query, _), do: query

  defp object_ids_query_for_tags(tags) do
    from(hto in "hashtags_objects")
    |> join(:inner, [hto], ht in Pleroma.Hashtag, on: hto.hashtag_id == ht.id)
    |> where([hto, ht], ht.name in ^tags)
    |> select([hto], hto.object_id)
    |> distinct([hto], true)
  end

  defp restrict_hashtag_all(_query, %{tag_all: _tag, skip_preload: true}) do
    raise_on_missing_preload()
  end

  defp restrict_hashtag_all(query, %{tag_all: [single_tag]}) do
    restrict_hashtag_any(query, %{tag: single_tag})
  end

  defp restrict_hashtag_all(query, %{tag_all: [_ | _] = tags}) do
    from(
      [_activity, object] in query,
      where:
        fragment(
          """
          (SELECT array_agg(hashtags.name) FROM hashtags JOIN hashtags_objects
            ON hashtags_objects.hashtag_id = hashtags.id WHERE hashtags.name = ANY(?)
              AND hashtags_objects.object_id = ?) @> ?
          """,
          ^tags,
          object.id,
          ^tags
        )
    )
  end

  defp restrict_hashtag_all(query, %{tag_all: tag}) when is_binary(tag) do
    restrict_hashtag_all(query, %{tag_all: [tag]})
  end

  defp restrict_hashtag_all(query, _), do: query

  defp restrict_hashtag_any(_query, %{tag: _tag, skip_preload: true}) do
    raise_on_missing_preload()
  end

  defp restrict_hashtag_any(query, %{tag: [_ | _] = tags}) do
    hashtag_ids =
      from(ht in Hashtag, where: ht.name in ^tags, select: ht.id)
      |> Repo.all()

    # Note: NO extra ordering should be done on "activities.id desc nulls last" for optimal plan
    from(
      [_activity, object] in query,
      join: hto in "hashtags_objects",
      on: hto.object_id == object.id,
      where: hto.hashtag_id in ^hashtag_ids,
      distinct: [desc: object.id],
      order_by: [desc: object.id]
    )
  end

  defp restrict_hashtag_any(query, %{tag: tag}) when is_binary(tag) do
    restrict_hashtag_any(query, %{tag: [tag]})
  end

  defp restrict_hashtag_any(query, _), do: query

  defp restrict_hashtag_reject_any(_query, %{tag_reject: _tag_reject, skip_preload: true}) do
    raise_on_missing_preload()
  end

  defp restrict_hashtag_reject_any(query, %{tag_reject: [_ | _] = tags_reject}) do
    from(
      [_activity, object] in query,
      where: object.id not in subquery(object_ids_query_for_tags(tags_reject))
    )
  end

  defp restrict_hashtag_reject_any(query, %{tag_reject: tag_reject}) when is_binary(tag_reject) do
    restrict_hashtag_reject_any(query, %{tag_reject: [tag_reject]})
  end

  defp restrict_hashtag_reject_any(query, _), do: query

  defp raise_on_missing_preload do
    raise "Can't use the child object without preloading!"
  end

  defp restrict_recipients(query, [], _user), do: query

  defp restrict_recipients(query, [recipient], nil) do
    from(activity in query, where: fragment("? = ANY(?)", ^recipient, activity.recipients))
  end

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

  # Essentially, either look for activities addressed to `recipients`, _OR_ ones
  # that reference a hashtag that the user follows
  # Firstly, two fallbacks in case there's no hashtag constraint, or the user doesn't
  # follow any
  defp restrict_recipients_or_hashtags(query, recipients, user, nil) do
    restrict_recipients(query, recipients, user)
  end

  defp restrict_recipients_or_hashtags(query, recipients, user, []) do
    restrict_recipients(query, recipients, user)
  end

  defp restrict_recipients_or_hashtags(query, recipients, _user, hashtag_ids) do
    from([activity, object] in query)
    |> join(:left, [activity, object], hto in "hashtags_objects",
      on: hto.object_id == object.id,
      as: :hto
    )
    |> where(
      [activity, object, hto: hto],
      (hto.hashtag_id in ^hashtag_ids and ^Constants.as_public() in activity.recipients) or
        fragment("? && ?", ^recipients, activity.recipients)
    )
  end

  defp restrict_local(query, %{local_only: true}) do
    from(activity in query, where: activity.local == true)
  end

  defp restrict_local(query, _), do: query

  defp restrict_remote(query, %{remote: true}) do
    from(activity in query, where: activity.local == false)
  end

  defp restrict_remote(query, _), do: query

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

  defp restrict_muted(query, opts) do
    query
    |> restrict_muted_users(opts)
    |> restrict_muted_threads(opts)
  end

  defp restrict_muted_users(query, %{with_muted: true}), do: query

  defp restrict_muted_users(query, %{muting_user: %User{} = user} = opts) do
    mutes = opts[:muted_users_ap_ids] || User.muted_users_ap_ids(user)

    from([activity] in query,
      where: fragment("not (? = ANY(?))", activity.actor, ^mutes),
      where:
        fragment(
          "not (?->'to' \\?| ?) or ? = ?",
          activity.data,
          ^mutes,
          activity.actor,
          ^user.ap_id
        )
    )
  end

  defp restrict_muted_users(query, _), do: query

  defp restrict_muted_threads(query, %{with_muted: true}), do: query

  defp restrict_muted_threads(query, %{muting_user: %User{} = _user} = opts) do
    unless opts[:skip_preload] do
      from([thread_mute: tm] in query, where: is_nil(tm.user_id))
    else
      query
    end
  end

  defp restrict_muted_threads(query, _), do: query

  defp restrict_blocked_users(query, _, []), do: query

  defp restrict_blocked_users(query, user, blocked_ap_ids) do
    query
    # You don't block the author
    |> where([activity], fragment("not (? = ANY(?))", activity.actor, ^blocked_ap_ids))
    # You don't block any recipients, and didn't author the post
    |> where(
      [activity],
      fragment(
        "((not (? && ?)) or ? = ?)",
        activity.recipients,
        ^blocked_ap_ids,
        activity.actor,
        ^user.ap_id
      )
    )
    # It's not a boost of a user you block
    |> where(
      [activity],
      fragment(
        "not (?->>'type' = 'Announce' and ?->'to' \\?| ?)",
        activity.data,
        activity.data,
        ^blocked_ap_ids
      )
    )
  end

  defp restrict_blocked_domains(query, _, []), do: query

  defp restrict_blocked_domains(query, user, domain_blocks) do
    following_ap_ids = User.get_friends_ap_ids(user)

    query =
      if has_named_binding?(query, :object), do: query, else: Activity.with_joined_object(query)

    from(
      [activity, object: o] in query,
      # You don't block the domain of any recipients, and didn't author the post
      where:
        fragment(
          "(recipients_contain_blocked_domains(?, ?) = false) or ? = ?",
          activity.recipients,
          ^domain_blocks,
          activity.actor,
          ^user.ap_id
        ),

      # You don't block the author's domain, and also don't follow the author
      where:
        fragment(
          "(not (split_part(?, '/', 3) = ANY(?))) or ? = ANY(?)",
          activity.actor,
          ^domain_blocks,
          activity.actor,
          ^following_ap_ids
        ),

      # Same as above, but checks the Object
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

  defp restrict_blocked(query, %{blocking_user: %User{} = user} = opts) do
    blocked_ap_ids = opts[:blocked_users_ap_ids] || User.blocked_users_ap_ids(user)
    domain_blocks = user.domain_blocks || []

    query
    |> restrict_blocked_users(user, blocked_ap_ids)
    |> restrict_blocked_domains(user, domain_blocks)
  end

  defp restrict_blocked(query, _), do: query

  defp restrict_blockers_visibility(query, %{blocking_user: %User{} = user}) do
    with false <- Config.get([:activitypub, :blockers_visible]),
         blocker_ap_ids <- User.incoming_relationships_ungrouped_ap_ids(user, [:block]),
         false <- blocker_ap_ids == [] do
      from(
        activity in query,
        # The author doesn't block you
        where: fragment("not (? = ANY(?))", activity.actor, ^blocker_ap_ids),

        # It's not a boost of a user that blocks you
        where:
          fragment(
            "not (?->>'type' = 'Announce' and ?->'to' \\?| ?)",
            activity.data,
            activity.data,
            ^blocker_ap_ids
          )
      )
    else
      _ -> query
    end
  end

  defp restrict_blockers_visibility(query, _), do: query

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

  defp restrict_pinned(query, %{pinned: true, pinned_object_ids: ids}) do
    from(
      [activity, object: o] in query,
      where:
        fragment(
          "(?)->>'type' = 'Create' and coalesce((?)->'object'->>'id', (?)->>'object') = any (?)",
          activity.data,
          activity.data,
          activity.data,
          ^ids
        )
    )
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

  defp restrict_instance(query, %{instance: instance}) when is_binary(instance) do
    from(
      activity in query,
      where: fragment("split_part(actor::text, '/'::text, 3) = ?", ^instance)
    )
  end

  defp restrict_instance(query, %{instance: instance}) when is_list(instance) do
    from(
      activity in query,
      where: fragment("split_part(actor::text, '/'::text, 3) = ANY(?)", ^instance)
    )
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

  defp exclude_invisible_actors(query, %{type: "Flag"}), do: query
  defp exclude_invisible_actors(query, %{invisible_actors: true}), do: query

  defp exclude_invisible_actors(query, _opts) do
    query
    |> join(:inner, [activity], u in User,
      as: :u,
      on: activity.actor == u.ap_id and u.invisible == false
    )
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

  defp normalize_fetch_activities_query_opts(opts) do
    Enum.reduce([:tag, :tag_all, :tag_reject], opts, fn key, opts ->
      case opts[key] do
        value when is_bitstring(value) ->
          Map.put(opts, key, Hashtag.normalize_name(value))

        value when is_list(value) ->
          normalized_value =
            value
            |> Enum.map(&Hashtag.normalize_name/1)
            |> Enum.uniq()

          Map.put(opts, key, normalized_value)

        _ ->
          opts
      end
    end)
  end

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
    opts = normalize_fetch_activities_query_opts(opts)

    {restrict_blocked_opts, restrict_muted_opts, restrict_muted_reblogs_opts} =
      fetch_activities_query_ap_ids_ops(opts)

    query =
      Activity
      |> maybe_preload_objects(opts)
      |> maybe_preload_bookmarks(opts)
      |> maybe_preload_report_notes(opts)
      |> maybe_set_thread_muted_field(opts)
      |> maybe_order(opts)
      |> restrict_recipients_or_hashtags(recipients, opts[:user], opts[:followed_hashtags])
      |> restrict_replies(opts)
      |> restrict_since(opts)
      |> restrict_local(opts)
      |> restrict_remote(opts)
      |> restrict_actor(opts)
      |> restrict_type(opts)
      |> restrict_state(opts)
      |> restrict_favorited_by(opts)
      |> restrict_blocked(restrict_blocked_opts)
      |> restrict_blockers_visibility(opts)
      |> restrict_muted(restrict_muted_opts)
      |> restrict_filtered(opts)
      |> restrict_media(opts)
      |> restrict_reblogs(opts)
      |> restrict_pinned(opts)
      |> restrict_muted_reblogs(restrict_muted_reblogs_opts)
      |> restrict_instance(opts)
      |> restrict_announce_object_actor(opts)
      |> maybe_restrict_deactivated_users(opts)
      |> exclude_poll_votes(opts)
      |> exclude_invisible_actors(opts)

    if Config.feature_enabled?(:improved_hashtag_timeline) do
      query
      |> restrict_hashtag_any(opts)
      |> restrict_hashtag_all(opts)
      |> restrict_hashtag_reject_any(opts)
    else
      query
      |> restrict_embedded_tag_any(opts)
      |> restrict_embedded_tag_all(opts)
      |> restrict_embedded_tag_reject_any(opts)
    end
  end

  @doc """
  Fetch posts liked by the given user wrapped in a paginated list with IDs taken from the like activity
  """
  @spec fetch_favourited_with_fav_id(User.t(), map()) ::
          list(%{id: binary(), entry: Activity.t()})
  def fetch_favourited_with_fav_id(user, params \\ %{}) do
    user.ap_id
    |> Activity.Queries.by_actor()
    |> Activity.Queries.by_type("Like")
    |> Activity.with_joined_object()
    |> Object.with_joined_activity()
    |> select([like, object, create], %{id: like.id, entry: %{create | object: object}})
    |> Pagination.fetch_paginated(params, :keyset)
  end

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
    with {:ok, data} <- Upload.store(sanitize_upload_file(file), opts) do
      obj_data = Maps.put_if_present(data, "actor", opts[:actor])

      Repo.insert(%Object{data: obj_data})
    end
  end

  defp sanitize_upload_file(%Plug.Upload{filename: filename} = upload) when is_binary(filename) do
    %Plug.Upload{
      upload
      | filename: Path.basename(filename)
    }
  end

  defp sanitize_upload_file(upload), do: upload

  defp maybe_restrict_deactivated_users(activity, %{type: "Flag"}), do: activity

  defp maybe_restrict_deactivated_users(activity, _opts),
    do: Activity.restrict_deactivated_users(activity)
end
