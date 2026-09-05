# General Performance and Optimisation Notes

# Oban Web

The built-in Oban Web dashboard has a seemingly constant'ish overhead
irrelevant to large instances but potentially
noticeable for small instances on low power systems.
Thus if the latter applies to your case, you might want to disable it;
see [the cheatsheet](../cheatsheet.md#oban-web).

# Relays

Subscribing to relays exposes your instance to a high volume flood of incoming activities.
This does not just incur the cost of processing those activities themselves, but typically
each activity may trigger additional work, like fetching ancestors and child posts to
complete the thread, refreshing user profiles, etc.  
Furthermore the larger the count of activities and objects in your database the costlier
all database operations on these (highly important) tables get.

Carefully consider whether this is worth the cost
and if you experience performance issues unsubscribe from relays.

Regularly pruning old remote posts and orphaned activities is also especially important
when following relays or just having unfollowed relays for performance reasons.

# Pruning old remote data

Over time your instance accumulates more and more remote data, mainly in form of posts and activities.
Chances are you and your local users do not actually care for the vast majority of those.
Consider regularly *(frequency highly dependent on your individual setup)* pruning such old and irrelevant remote data; see
[the corresponding `mix` tasks](../../../administration/CLI_tasks/database#prune-old-remote-posts-from-the-database).

# Database Maintenance

Akkoma’s performance is highly dependent on and often bottle-necked by the database.
Taking good care of it pays off!
See the dedicated [PostgreSQL page](../postgresql.md).

# HTTP Request Cache

If your instance is frequently getting _many_ `GET` requests from external 
actors *(i.e. everyone except logged-in local users)* an additional
*(Akkoma already has some caching built-in and so might your reverse proxy)*
caching layer as described in the [Varnish Cache guide](varnish_cache.md)
might help alleviate the impact.

If this condition does **not** hold though,
setting up such a cache likely only worsens latency and wastes memory.

# Ulimits

Large instances may run into issues with too restrictive OS limits,
such as `nofile` (the maximum number of open file descriptors).
For `nofile` specifically, excessively large values can cause issues too however,
since BEAM will allocate a port management structure whose size is based
on this maximum leading to just as excessive RAM usage.

On many distros the default limits per user can be configured in a file
like `/etc/security/limits.conf` (see `man 5 limits.conf`) or an equivalent.
Remember to change both soft and hard limits, such that the hard limit is
always greater or equal to the soft limit.  
You can always lower (but not raise) the limits dynamically for initial testing
using e.g. `ulimit -Sn 65536 && /usr/bin/mix phx.server` *(this changes just the soft limit)*.

Our Docker setup initialises the `nofile` limit to a reasonable default.
If needed it can be changed via the `nofile` key in `ulimits` section
of the `akkoma` service; either in `docker-compose.yml` directly,
using the `docker-compose.override.yml` file or without recompiling the
container image via `docker run --ulimit …`.

# DB Search Fuzziness

If using the default database search with a GIN (not RUM!) index
and specifically search database queries hog up unacceptably
much database time, you may cap this impact in exchange for
worse and unstable search results.  
See [Search Configuraton](../search.md).

This should not be necessary on all but the largest or oldest unpruned servers.
Also when evaluating search performance keep in mind the time the API endpoint
takes to respond is not the same as the database time. In particular when
searching for URLs they may be fetched via the network taking orders of magnitudes
longer than any normal database query.
