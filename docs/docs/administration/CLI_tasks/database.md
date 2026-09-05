# Database maintenance tasks

{! administration/CLI_tasks/general_cli_task_info.include !}

!!! danger
    These mix tasks can take a long time to complete. Many of them were written to address specific database issues that happened because of bugs in migrations or other specific scenarios. Do not run these tasks "just in case" if everything is fine your instance.

## Replace embedded objects with their references

Replaces embedded objects with references to them in the `objects` table. Only needs to be ran once if the instance was created before Pleroma 1.0.5. The reason why this is not a migration is because it could significantly increase the database size after being ran, however after this `VACUUM FULL` will be able to reclaim about 20% (really depends on what is in the database, your mileage may vary) of the database size before the migration.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database remove_embedded_objects [option ...]
    ```

=== "From Source"

    ```sh
    mix pleroma.database remove_embedded_objects [option ...]
    ```

### Options
- `--vacuum` - run `VACUUM FULL` after the embedded objects are replaced with their references

## Prune old remote posts from the database

This will selectively prune remote posts older than 90 days (configurable with [`config :pleroma, :instance, remote_post_retention_days`](../../configuration/cheatsheet.md#instance)) from the database. Pruned posts may be refetched in some cases.

!!! note
    The disk space used up by deleted rows only becomes usable for new data after a vaccum.
    By default, Postgresql does this for you on a regular basis, but if you delete a lot at once
    it might be advantageous to also manually kick off a vacuum and statistics update using `VACUUM ANALYZE`.

    **However**, the freed up space is never returned to the operating system unless you run
    the much more heavy `VACUUM FULL` operation. This epensive but comprehensive vacuum mode
    can be schedlued using the `--vacuum` option.

!!! danger
    You may run out of disk space during the execution of the task or full vacuuming if you don't have about 1/3rds of the database size free. `VACUUM FULL` causes a substantial increase in I/O traffic, needs full table locks and thus renders the instance basically unusable while its running.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database prune_objects [option ...]
    ```

=== "From Source"

    ```sh
    mix pleroma.database prune_objects [option ...]
    ```

### Options

The recommended starting point and configuration for small and medium-sized instances is:
```sh
prune_objects --keep-followed posts --keep-threads --keep-non-public
# followed by
prune_orphaned_activities --no-singles
prune_orphaned_activities --no-arrays
# and finally, using psql to manually run:
#   VACUUM ANALYZE;
#   REINDEX TABLE objects;
#   REINDEX TABLE activities;
```
This almost certainly won’t delete stuff your interested in and
makes sure the database is immediately utilising the newly freed up space.
If you need more aggressive database size reductions or if this proves too costly to run for you
you can drop restrictions and/or use the `--limit` option.
In the opposite case if everything goes through quickly,
you can combine the three CLI tasks into one for future runs using `--prune-orphaned-activities`
and perhaps even using a full vacuum (which implies a reindex) using `--vacuum` too.

Full details below:

- `--no-fix-replies-count` - Skip recalculating replies count for posts.  
    When using multiple batches of prunes with `--limit`, all but the last batch
    should set this option to avoid unnecessary overhead.
- `--keep-followed <mode>` - If set to `posts` all posts and boosts of users with local follows will be kept.  
    If set to `full` it will additionally keep any posts such users interacted with; this requires `--keep-threads`.  
    By default this is set to `none` and followed users are not treated special.
- `--keep-threads` - Don't prune posts when they are part of a thread where at least one post has seen local interaction (e.g. one of the posts is a local post, or is favourited by a local user, or has been repeated by a local user...). It also won’t delete posts when at least one of the posts in the thread has seen recent activity or is kept due to `--keep-followed`.
- `--keep-non-public` - Keep non-public posts like DM's and followers-only, even if they are remote.
- `--limit` - limits how many remote posts get pruned. This limit does **not** apply to any of the follow up jobs. If wanting to keep the database load in check it is thus advisable to run the standalone `prune_orphaned_activities` task with a limit afterwards instead of passing `--prune-orphaned-activities` to this task.
    See documentation of other options for futher hints.
- `--prune-orphaned-activities` - Also prune orphaned activities afterwards. Activities are things like Like, Create, Announce, Flag (aka reports)... They can significantly help reduce the database size.
- `--prune-pinned` - Also prune pinned posts; keeping pinned posts does not suffice to protect their threads from pruning, even when using `--keep-threads`.  
    Note, if using this option and pinned posts are pruned, they and their threads will just be refetched on the next user update. Therefore it usually doesn't bring much gain while incurring a heavy fetch load after pruning.  
    One exception to this is if you already need to use a relatively small `--limit` to keep downtime mangeable or even being able to run it without downtime. Retaining pinned posts adds a mostly constant overhead which will impact repeated runs with small limit much more than one full prune run.
- `--vacuum` - Run `VACUUM FULL` after the objects are pruned. This should not be used on a regular basis, but is useful if your instance has been running for a long time before pruning.

## Prune orphaned activities from the database

This will prune activities which are no longer referenced by anything.
Such activities might be the result of running `prune_objects` without `--prune-orphaned-activities`.
The same notes and warnings apply as for `prune_objects`.

The task will print out how many rows were freed in total in its last
line of output in the form `Deleted 345 rows`.  
When running the job in limited batches this can be used to determine
when all orphaned activities have been deleted.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database prune_orphaned_activities [option ...]
    ```

=== "From Source"

    ```sh
    mix pleroma.database prune_orphaned_activities [option ...]
    ```

### Options

- `--limit n` - Only delete up to `n` activities in each query making up this job, i.e. if this job runs two queries at most `2n` activities will be deleted. Running this task repeatedly in limited batches can help maintain the instance’s responsiveness while still freeing up some space.
- `--no-singles` - Do not delete activites referencing single objects
- `--no-arrays` - Do not delete activites referencing an array of objects

## Remove duplicated items from following and update followers count for all users

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database update_users_following_followers_counts
    ```

=== "From Source"

    ```sh
    mix pleroma.database update_users_following_followers_counts
    ```

## Fix the pre-existing "likes" collections for all objects

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database fix_likes_collections
    ```

=== "From Source"

    ```sh
    mix pleroma.database fix_likes_collections
    ```

## Vacuum the database

!!! note
    By default, Postgresql has an autovacuum daemon running. While the tasks described here can help in some cases, they shouldn't be needed on a regular basis. See [the Postgresql docs on vacuuming](https://www.postgresql.org/docs/current/sql-vacuum.html) for more information on this.

### Analyze

Running an `analyze` vacuum job can improve performance by updating statistics used by the query planner. **It is safe to cancel this.**

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database vacuum analyze
    ```

=== "From Source"

    ```sh
    mix pleroma.database vacuum analyze
    ```

### Full

Running a `full` vacuum job rebuilds your entire database by reading all data and rewriting it into smaller
and more compact files with an optimized layout. This process will take a long time and use additional disk space as
it builds the files side-by-side the existing database files. It can make your database faster and use less disk space,
but should only be run if necessary. **It is safe to cancel this.**

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database vacuum full
    ```

=== "From Source"

    ```sh
    mix pleroma.database vacuum full
    ```

## Add expiration to all local statuses

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database ensure_expiration
    ```

=== "From Source"

    ```sh
    mix pleroma.database ensure_expiration
    ```

## Change Text Search Configuration

Change `default_text_search_config` for database and (if necessary) text_search_config used in index, then rebuild index (it may take time).

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database set_text_search_config english
    ```

=== "From Source"

    ```sh
    mix pleroma.database set_text_search_config english
    ```

See [PostgreSQL documentation](https://www.postgresql.org/docs/current/textsearch-configuration.html) and `docs/configuration/howto_search_cjk.md` for more detail.

## Pruning old activities

Over time, transient `Delete` activities and `Tombstone` objects
can accumulate in your database, inflating its size. This is not ideal.
There is a periodic task to prune these transient objects,
but on the first run this may take a while on older instances to catch up
to the current day.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database prune_task
    ```

=== "From Source"

    ```sh
    mix pleroma.database prune_task
    ```

## Clean inlined replies lists

Those inlined arrays of replies AP IDs are not used (anymore).
Delete them to free up a little bit of space.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database clean_inlined_replies
    ```

=== "From Source"

    ```sh
    mix pleroma.database clean_inlined_replies
    ```

## Resync data inlined into posts

For legacy and performance reasons some data, e.g. relating to likes and boosts,
is currently copied and inline references post objects. Occasionally this data
may desync from the actual authorative activity and object data stored in the
database which may lead to cosmetic but also functional issues.
For example a particular user may appear unable to like a post.
Run this task to detect and fix such desyncs.

=== "OTP"

    ```sh
    ./bin/pleroma_ctl database resync_inlined_caches
    ```

=== "From Source"

    ```sh
    mix pleroma.database resync_inlined_caches
    ```

### Options

- `--no-announcements` - Skip fixing announcement counters and lists
- `--no-likes` - Skip fixing like counters and lists
- `--no-reactions` - Skip fixing inlined emoji reaction data
- `--no-replies-count` - Skip fixing replies counters (purely cosmetic)
