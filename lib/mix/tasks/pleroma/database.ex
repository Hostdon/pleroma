# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.Database do
  alias Pleroma.Maintenance
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User

  require Logger
  require Pleroma.Constants

  import Ecto.Query
  import Mix.Pleroma

  use Mix.Task

  @shortdoc "A collection of database related tasks"
  @moduledoc File.read!("docs/docs/administration/CLI_tasks/database.md")

  defp maybe_concat(str, condition, appendix) do
    if condition, do: str <> appendix, else: str
  end

  defp maybe_limit(query, limit_cnt) do
    if is_number(limit_cnt) and limit_cnt > 0 do
      limit(query, [], ^limit_cnt)
    else
      query
    end
  end

  defp limit_statement(limit) when is_number(limit) do
    if limit > 0 do
      "LIMIT #{limit}"
    else
      ""
    end
  end

  defp prune_orphaned_activities_singles(limit) do
    %{:num_rows => del_single} =
      """
      delete from public.activities
      where id in (
        select a.id from public.activities a
        left join public.objects o on a.data ->> 'object' = o.data ->> 'id'
        left join public.activities a2 on a.data ->> 'object' = a2.data ->> 'id'
        left join public.users u  on a.data ->> 'object' = u.ap_id
        where not a.local
        and jsonb_typeof(a."data" -> 'object') = 'string'
        and o.id is null
        and a2.id is null
        and u.id is null
        #{limit_statement(limit)}
      )
      """
      |> Repo.query!([], timeout: :infinity)

    Logger.info("Prune activity singles: deleted #{del_single} rows...")
    del_single
  end

  defp prune_orphaned_activities_array(limit) do
    %{:num_rows => del_array} =
      """
      delete from public.activities
      where id in (
        select a.id from public.activities a
        join json_array_elements_text((a."data" -> 'object')::json) as j
             on a.data->>'type' = 'Flag'
        left join public.objects o on j.value = o.data ->> 'id'
        left join public.activities a2 on j.value = a2.data ->> 'id'
        left join public.users u  on j.value = u.ap_id
        group by a.id
        having max(o.data ->> 'id') is null
        and max(a2.data ->> 'id') is null
        and max(u.ap_id) is null
        #{limit_statement(limit)}
      )
      """
      |> Repo.query!([], timeout: :infinity)

    Logger.info("Prune activity arrays: deleted #{del_array} rows...")
    del_array
  end

  def prune_orphaned_activities(limit \\ 0, opts \\ []) when is_number(limit) do
    # Activities can either refer to a single object id, and array of object ids
    # or contain an inlined object (at least after going through our normalisation)
    #
    # Flag is the only type we support with an array (and always has arrays).
    # Update the only one with inlined objects.
    #
    # We already regularly purge old Delete, Undo, Update and Remove and if
    # rejected Follow requests anyway; no need to explicitly deal with those here.
    #
    # Since there’s an index on types and there are typically only few Flag
    # activites, it’s _much_ faster to utilise the index. To avoid accidentally
    # deleting useful activities should more types be added, keep typeof for singles.

    # Prune activities who link to an array of objects
    del_array =
      if Keyword.get(opts, :arrays, true) do
        prune_orphaned_activities_array(limit)
      else
        0
      end

    # Prune activities who link to a single object
    del_single =
      if Keyword.get(opts, :singles, true) do
        prune_orphaned_activities_singles(limit)
      else
        0
      end

    del_single + del_array
  end

  defp query_pinned_object_apids() do
    Pleroma.User
    |> select([u], %{ap_id: fragment("jsonb_object_keys(?)", u.pinned_objects)})
  end

  defp query_pinned_object_ids() do
    # If this additional level of subquery is omitted and we directly supply AP ids
    # to te final query, it appears to overexert PostgreSQL(17)'s planner leading
    # to a very inefficient query with enormous memory and time consumption.
    # By supplying database IDs it ends up quite cheap however.
    Object
    |> where([o], fragment("?->>'id' IN ?", o.data, subquery(query_pinned_object_apids())))
    |> select([o], o.id)
  end

  defp query_followed_remote_user_apids() do
    Pleroma.FollowingRelationship
    |> join(:inner, [rel], ufing in User, on: rel.following_id == ufing.id)
    |> join(:inner, [rel], ufer in User, on: rel.follower_id == ufer.id)
    |> where([rel], rel.state == :follow_accept)
    |> where([_rel, ufing, ufer], ufer.local and not ufing.local)
    |> select([_rel, ufing], %{ap_id: ufing.ap_id})
  end

  defp parse_keep_followed_arg(options) do
    case Keyword.get(options, :keep_followed) do
      "full" -> :full
      "posts" -> :posts
      "none" -> false
      nil -> false
      _ -> raise "Invalid argument for keep_followed! Must be 'full', 'posts' or 'none'"
    end
  end

  defp maybe_restrict_followed_activities(query, options) do
    case Keyword.get(options, :keep_followed) do
      :full ->
        having(
          query,
          [a],
          fragment(
            "bool_and(?->>'actor' NOT IN ?)",
            a.data,
            subquery(query_followed_remote_user_apids())
          )
        )

      :posts ->
        having(
          query,
          [a],
          not fragment(
            "bool_or(?->>'actor' IN ? AND ?->>'type' = ANY('{Create,Announce}'))",
            a.data,
            subquery(query_followed_remote_user_apids()),
            a.data
          )
        )

      _ ->
        query
    end
  end

  defp deletable_objects_keeping_threads(time_deadline, limit_cnt, options) do
    # We want to delete objects from threads where
    # 1. the newest post is still old
    # 2. none of the activities is local
    # 3. none of the activities is bookmarked
    # 4. optionally none of the posts is non-public
    deletable_context =
      if Keyword.get(options, :keep_non_public) do
        Pleroma.Activity
        |> join(:left, [a], b in Pleroma.Bookmark, on: a.id == b.activity_id)
        |> group_by([a], fragment("? ->> 'context'::text", a.data))
        |> having(
          [a],
          not fragment(
            # Posts (checked on Create Activity) is non-public
            "bool_or((not(?->'to' \\? ? OR ?->'cc' \\? ?)) and ? ->> 'type' = 'Create')",
            a.data,
            ^Pleroma.Constants.as_public(),
            a.data,
            ^Pleroma.Constants.as_public(),
            a.data
          )
        )
      else
        Pleroma.Activity
        |> join(:left, [a], b in Pleroma.Bookmark, on: a.id == b.activity_id)
        |> group_by([a], fragment("? ->> 'context'::text", a.data))
      end
      |> having([a], max(a.updated_at) < ^time_deadline)
      |> having([a], not fragment("bool_or(?)", a.local))
      |> having([_, b], fragment("max(?::text) is null", b.id))
      |> maybe_restrict_followed_activities(options)
      |> maybe_limit(limit_cnt)
      |> select([a], fragment("? ->> 'context'::text", a.data))

    Pleroma.Object
    |> where([o], fragment("? ->> 'context'::text", o.data) in subquery(deletable_context))
  end

  defp deletable_objects_breaking_threads(time_deadline, limit_cnt, options) do
    deletable =
      if Keyword.get(options, :keep_non_public) do
        Pleroma.Object
        |> where(
          [o],
          fragment(
            "?->'to' \\? ? OR ?->'cc' \\? ?",
            o.data,
            ^Pleroma.Constants.as_public(),
            o.data,
            ^Pleroma.Constants.as_public()
          )
        )
      else
        Pleroma.Object
      end
      |> where([o], o.updated_at < ^time_deadline)
      |> where(
        [o],
        fragment("split_part(?->>'actor', '/', 3) != ?", o.data, ^Pleroma.Web.Endpoint.host())
      )
      |> then(fn q ->
        if Keyword.get(options, :keep_followed) do
          where(
            q,
            [o],
            fragment("?->>'actor'", o.data) not in subquery(query_followed_remote_user_apids())
          )
        else
          q
        end
      end)
      |> maybe_limit(limit_cnt)
      |> select([o], o.id)

    Pleroma.Object
    |> where([o], o.id in subquery(deletable))
  end

  def run(["remove_embedded_objects" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          vacuum: :boolean
        ]
      )

    start_pleroma()
    Logger.info("Removing embedded objects")

    Repo.query!(
      "update activities set data = safe_jsonb_set(data, '{object}'::text[], data->'object'->'id') where data->'object'->>'id' is not null;",
      [],
      timeout: :infinity
    )

    if Keyword.get(options, :vacuum) do
      Maintenance.vacuum("full")
    end
  end

  def run(["update_users_following_followers_counts"]) do
    start_pleroma()

    Repo.transaction(
      fn ->
        from(u in User, select: u, where: u.local or u.is_active)
        |> Repo.stream()
        |> Stream.each(&User.update_follower_count/1)
        |> Stream.run()
      end,
      timeout: :infinity
    )
  end

  def run(["prune_orphaned_activities" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          limit: :integer,
          singles: :boolean,
          arrays: :boolean
        ]
      )

    start_pleroma()

    {limit, options} = Keyword.pop(options, :limit, 0)

    "Pruning orphaned activities"
    |> maybe_concat(limit > 0, ", limiting deletion to #{limit} rows")
    |> Logger.info()

    deleted = prune_orphaned_activities(limit, options)

    Logger.info("Deleted #{deleted} rows")
  end

  def run(["prune_objects" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          vacuum: :boolean,
          keep_followed: :string,
          keep_threads: :boolean,
          keep_non_public: :boolean,
          prune_orphaned_activities: :boolean,
          prune_pinned: :boolean,
          fix_replies_count: :boolean,
          limit: :integer
        ]
      )

    kf = parse_keep_followed_arg(options)
    options = Keyword.put(options, :keep_followed, kf)

    if kf == :full and not Keyword.get(options, :keep_threads) do
      raise "keep_followed=full only works in conjunction with keep_thread!"
    end

    start_pleroma()

    deadline = Pleroma.Config.get([:instance, :remote_post_retention_days])
    time_deadline = NaiveDateTime.utc_now() |> NaiveDateTime.add(-(deadline * 86_400))

    limit_cnt = Keyword.get(options, :limit, 0)

    "Pruning objects older than #{deadline} days"
    |> maybe_concat(Keyword.get(options, :keep_non_public), ", keeping non public posts")
    |> maybe_concat(Keyword.get(options, :keep_threads), ", keeping threads intact")
    |> maybe_concat(kf, ", keeping #{kf} activities of followed users")
    |> maybe_concat(Keyword.get(options, :prune_pinned), ", pruning pinned posts")
    |> maybe_concat(
      Keyword.get(options, :prune_orphaned_activities),
      ", pruning orphaned activities"
    )
    |> maybe_concat(
      Keyword.get(options, :vacuum),
      ", doing a full vacuum (you shouldn't do this as a recurring maintanance task)"
    )
    |> maybe_concat(limit_cnt > 0, ", limiting to #{limit_cnt} rows")
    |> Logger.info()

    {del_obj, _} =
      if Keyword.get(options, :keep_threads) do
        deletable_objects_keeping_threads(time_deadline, limit_cnt, options)
      else
        deletable_objects_breaking_threads(time_deadline, limit_cnt, options)
      end
      |> then(fn q ->
        if Keyword.get(options, :prune_pinned) do
          q
        else
          where(q, [o], o.id not in subquery(query_pinned_object_ids()))
        end
      end)
      |> Repo.delete_all(timeout: :infinity)

    Logger.info("Deleted #{del_obj} objects...")

    if !Keyword.get(options, :keep_threads) do
      # Without the --keep-threads option, it's possible that bookmarked
      # objects have been deleted. We remove the corresponding bookmarks.
      %{:num_rows => del_bookmarks} =
        """
        delete from public.bookmarks
        where id in (
          select b.id from public.bookmarks b
          left join public.activities a on b.activity_id = a.id
          left join public.objects o on a."data" ->> 'object' = o.data ->> 'id'
          where o.id is null
        )
        """
        |> Repo.query!([], timeout: :infinity)

      Logger.info("Deleted #{del_bookmarks} orphaned bookmarks...")
    end

    if Keyword.get(options, :prune_orphaned_activities) do
      del_activities = prune_orphaned_activities()
      Logger.info("Deleted #{del_activities} orphaned activities...")
    end

    %{:num_rows => del_hashtags} =
      """
      DELETE FROM hashtags
      USING hashtags AS ht
      LEFT JOIN hashtags_objects hto
            ON ht.id = hto.hashtag_id
      LEFT JOIN user_follows_hashtag ufht
            ON ht.id = ufht.hashtag_id
      WHERE
          hashtags.id = ht.id
          AND hto.hashtag_id is NULL
          AND ufht.hashtag_id is NULL
      """
      |> Repo.query!([], timeout: :infinity)

    Logger.info("Deleted #{del_hashtags} no longer used hashtags...")

    if Keyword.get(options, :fix_replies_count, true) do
      Logger.info("Fixing reply counters...")
      resync_replies_count()
    end

    if Keyword.get(options, :vacuum) do
      Logger.info("Starting vacuum...")
      Maintenance.vacuum("full")
    end

    Logger.info("All done!")
  end

  def run(["prune_task"]) do
    start_pleroma()

    nil
    |> Pleroma.Workers.Cron.PruneDatabaseWorker.perform()
  end

  # fixes wrong type of inlined like references for objects predating the inlined array
  def run(["fix_likes_collections"]) do
    start_pleroma()

    from(object in Object,
      where: fragment("(?)->>'likes' is not null", object.data),
      select: %{id: object.id, likes: fragment("(?)->>'likes'", object.data)}
    )
    |> Pleroma.Repo.chunk_stream(100, :batches)
    |> Stream.each(fn objects ->
      ids =
        objects
        |> Enum.filter(fn object -> object.likes |> Jason.decode!() |> is_map() end)
        |> Enum.map(& &1.id)

      Object
      |> where([object], object.id in ^ids)
      |> update([object],
        set: [
          data:
            fragment(
              "safe_jsonb_set(?, '{likes}', '[]'::jsonb, true)",
              object.data
            )
        ]
      )
      |> Repo.update_all([], timeout: :infinity)
    end)
    |> Stream.run()
  end

  def run(["vacuum", args]) do
    start_pleroma()

    Maintenance.vacuum(args)
  end

  def run(["ensure_expiration"]) do
    start_pleroma()
    days = Pleroma.Config.get([:mrf_activity_expiration, :days], 365)

    Pleroma.Activity
    |> join(:inner, [a], o in Object,
      on:
        fragment(
          "(?->>'id') = COALESCE((?)->'object'->> 'id', (?)->>'object')",
          o.data,
          a.data,
          a.data
        )
    )
    |> where(local: true)
    |> where([a], fragment("(? ->> 'type'::text) = 'Create'", a.data))
    |> where([_a, o], fragment("?->>'type' = 'Note'", o.data))
    |> Pleroma.Repo.chunk_stream(100, :batches)
    |> Stream.each(fn activities ->
      Enum.each(activities, fn activity ->
        expires_at =
          activity.inserted_at
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.shift(days: days)

        Pleroma.Workers.PurgeExpiredActivity.enqueue(%{
          activity_id: activity.id,
          expires_at: expires_at
        })
      end)
    end)
    |> Stream.run()
  end

  def run(["resync_inlined_caches" | args]) do
    {options, [], []} =
      OptionParser.parse(
        args,
        strict: [
          replies_count: :boolean,
          announcements: :boolean,
          likes: :boolean,
          reactions: :boolean
        ]
      )

    start_pleroma()

    if Keyword.get(options, :replies_count, true) do
      resync_replies_count()
    end

    if Keyword.get(options, :announcements, true) do
      resync_inlined_array("Announce", "announcement")
    end

    if Keyword.get(options, :likes, true) do
      resync_inlined_array("Like", "like")
    end

    if Keyword.get(options, :reactions, true) do
      resync_inlined_reactions()
    end
  end

  def run(["clean_inlined_replies"]) do
    # The inlined replies array is not used after the initial processing
    # when first receiving the object and only wastes space
    start_pleroma()

    # We cannot check jsonb_typeof(array) and jsonb_array_length() in the same query
    # since the checks do not short-circuit and NULL values will raise an error for the latter
    has_replies =
      Pleroma.Object
      |> select([o], %{id: o.id})
      |> where([o], fragment("jsonb_typeof(?->'replies') = 'array'", o.data))

    {update_cnt, _} =
      Pleroma.Object
      |> with_cte("arrays", as: ^has_replies)
      |> join(:inner, [o], a in "arrays", on: o.id == a.id)
      |> where([o, _a], fragment("jsonb_array_length(?->'replies') > 0", o.data))
      |> update(set: [data: fragment("jsonb_set(data, '{replies}', '[]'::jsonb)")])
      |> Pleroma.Repo.update_all([], timeout: :infinity)

    Logger.info("Emptied inlined replies lists from #{update_cnt} rows.")
  end

  def run(["set_text_search_config", tsconfig]) do
    start_pleroma()
    %{rows: [[tsc]]} = Ecto.Adapters.SQL.query!(Pleroma.Repo, "SHOW default_text_search_config;")
    shell_info("Current default_text_search_config: #{tsc}")

    %{rows: [[db]]} = Ecto.Adapters.SQL.query!(Pleroma.Repo, "SELECT current_database();")
    shell_info("Update default_text_search_config: #{tsconfig}")

    %{messages: msg} =
      Ecto.Adapters.SQL.query!(
        Pleroma.Repo,
        "ALTER DATABASE #{db} SET default_text_search_config = '#{tsconfig}';"
      )

    # non-exist config will not raise excpetion but only give >0 messages
    if length(msg) > 0 do
      shell_info("Error: #{inspect(msg, pretty: true)}")
    else
      rum_enabled = Pleroma.Config.get([:database, :rum_enabled])
      shell_info("Recreate index, RUM: #{rum_enabled}")

      # Note SQL below needs to be kept up-to-date with latest GIN or RUM index definition in future
      if rum_enabled do
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          "CREATE OR REPLACE FUNCTION objects_fts_update() RETURNS trigger AS $$ BEGIN
          new.fts_content := to_tsvector(COALESCE(new.data->>'summary', '') || ' ' || (new.data->>'content'));
          RETURN new;
          END
          $$ LANGUAGE plpgsql",
          [],
          timeout: :infinity
        )

        shell_info("Refresh RUM index")
        Ecto.Adapters.SQL.query!(Pleroma.Repo, "UPDATE objects SET updated_at = NOW();")
      else
        Ecto.Adapters.SQL.query!(Pleroma.Repo, "DROP INDEX IF EXISTS objects_fts;")

        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          CREATE INDEX CONCURRENTLY objects_fts ON objects USING gin(
            to_tsvector(
              '#{tsconfig}',
              COALESCE(data->>'summary', '') || ' ' || (data->>'content')
            )
          );
          """,
          [],
          timeout: :infinity
        )
      end

      shell_info(~c"Done.")
    end
  end

  # Rolls back a specific migration (leaving subsequent migrations applied).
  # WARNING: imposes a risk of unrecoverable data loss — proceed at your own responsibility.
  # Based on https://stackoverflow.com/a/53825840
  def run(["rollback", version]) do
    prompt = "SEVERE WARNING: this operation may result in unrecoverable data loss. Continue?"

    if shell_prompt(prompt, "n") in ~w(Yn Y y) do
      {_, result, _} =
        Ecto.Migrator.with_repo(Pleroma.Repo, fn repo ->
          version = String.to_integer(version)
          re = ~r/^#{version}_.*\.exs/
          path = Ecto.Migrator.migrations_path(repo)

          with {_, "" <> file} <- {:find, Enum.find(File.ls!(path), &String.match?(&1, re))},
               {_, [{mod, _} | _]} <- {:compile, Code.compile_file(Path.join(path, file))},
               {_, :ok} <- {:rollback, Ecto.Migrator.down(repo, version, mod)} do
            {:ok, "Reversed migration: #{file}"}
          else
            {:find, _} -> {:error, "No migration found with version prefix: #{version}"}
            {:compile, e} -> {:error, "Problem compiling migration module: #{inspect(e)}"}
            {:rollback, e} -> {:error, "Problem reversing migration: #{inspect(e)}"}
          end
        end)

      shell_info(inspect(result))
    end
  end

  defp resync_replies_count() do
    public_str = Pleroma.Constants.as_public()

    ref =
      Pleroma.Object
      |> select([o], %{apid: fragment("?->>'inReplyTo'", o.data), cnt: count()})
      |> where(
        [o],
        fragment("?->>'type' <> 'Answer'", o.data) and
          fragment("?->>'inReplyTo' IS NOT NULL", o.data) and
          (fragment("?->'to' @> ?::jsonb", o.data, ^public_str) or
             fragment("?->'cc' @> ?::jsonb", o.data, ^public_str))
      )
      |> group_by([o], fragment("?->>'inReplyTo'", o.data))

    {update_cnt, _} =
      Pleroma.Object
      |> with_cte("ref", as: ^ref)
      |> join(:inner, [o], r in "ref", on: fragment("?->>'id'", o.data) == r.apid)
      |> where([o, r], fragment("(?->>'repliesCount')::bigint <> ?", o.data, r.cnt))
      |> update([o, r],
        set: [data: fragment("jsonb_set(?, '{repliesCount}', to_jsonb(?))", o.data, r.cnt)]
      )
      |> Pleroma.Repo.update_all([], timeout: :infinity)

    Logger.info("Fixed reply counter for #{update_cnt} objects.")
  end

  defp resync_inlined_array(activity_type, basename) do
    array_name = basename <> "s"
    counter_name = basename <> "_count"

    ref =
      Pleroma.Activity
      |> select([a], %{
        apid: fragment("?->>'object'", a.data),
        correct: fragment("to_jsonb(ARRAY_AGG(?->>'actor'))", a.data)
      })
      |> where(
        [a],
        fragment("?->>'type' = ?", a.data, ^activity_type) and
          fragment("?->>'id' IS NOT NULL", a.data) and
          fragment("?->>'actor' IS NOT NULL", a.data)
      )
      |> group_by([a], fragment("?->>'object'", a.data))

    {update_cnt, _} =
      Pleroma.Object
      |> with_cte("ref", as: ^ref)
      |> join(:inner, [o], r in "ref", on: fragment("?->>'id'", o.data) == r.apid)
      |> where(
        [o, r],
        fragment("?->>'id' = ?", o.data, r.apid) and
          not (fragment("? @> (?->?)", r.correct, o.data, ^array_name) and
                 fragment("? <@ (?->?)", r.correct, o.data, ^array_name))
      )
      |> update([o, r],
        set: [
          data:
            fragment(
              "? || jsonb_build_object(?::text, jsonb_array_length(?::jsonb), ?::text, ?::jsonb)",
              o.data,
              ^counter_name,
              r.correct,
              ^array_name,
              r.correct
            )
        ]
      )
      |> Pleroma.Repo.update_all([], timeout: :infinity)

    Logger.info("Fixed inlined #{basename} array and counter for #{update_cnt} objects.")
  end

  defp resync_inlined_reactions() do
    expanded_ref =
      Pleroma.Activity
      |> select([a], %{
        apid: selected_as(fragment("?->>'object'", a.data), :apid),
        emoji_name: selected_as(fragment("TRIM(?->>'content', ':')", a.data), :emoji_name),
        actors: fragment("ARRAY_AGG(DISTINCT ?->>'actor')", a.data),
        url: selected_as(fragment("?#>>'{tag,0,icon,url}'", a.data), :url)
      })
      |> where(
        [a],
        fragment("?->>'type' = 'EmojiReact'", a.data) and
          fragment("?->>'actor' IS NOT NULL", a.data) and
          fragment("TRIM(?->>'content', ':') IS NOT NULL", a.data)
      )
      |> group_by([_], [selected_as(:apid), selected_as(:emoji_name), selected_as(:url)])

    ref =
      from(e in subquery(expanded_ref))
      |> select([e], %{
        apid: e.apid,
        correct:
          fragment(
            "jsonb_agg(DISTINCT ARRAY[to_jsonb(?), to_jsonb(?), to_jsonb(?)])",
            e.emoji_name,
            e.actors,
            e.url
          )
      })
      |> group_by([e], e.apid)

    {update_cnt, _} =
      Pleroma.Object
      |> join(:inner, [o], r in subquery(ref), on: r.apid == fragment("?->>'id'", o.data))
      |> where(
        [o, r],
        not (fragment("? @> (?->'reactions')", r.correct, o.data) and
               fragment("? <@ (?->'reactions')", r.correct, o.data))
      )
      |> update([o, r],
        set: [data: fragment("jsonb_set(?, '{reactions}', ?)", o.data, r.correct)]
      )
      |> Pleroma.Repo.update_all([], timeout: :infinity)

    Logger.info("Fixed inlined emoji reactions for #{update_cnt} objects.")
  end
end
