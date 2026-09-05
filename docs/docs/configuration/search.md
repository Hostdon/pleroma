# Configuring search

{! administration/CLI_tasks/general_cli_task_info.include !}

## General

Processing of each search request is capped.
If a search exceeds this limit, the API will return an empty result for the affected category.
Too large values might end up capped by Cowboy’s HTTP request idle timeout, killing the whole response.
The value can be configured with:

```elixir
config :pleroma, Pleroma.Search, task_timeout: 51_610
```

## Search providers
### Built-in search

To use built-in search that has no external dependencies, set the search module to `Pleroma.Activity`:

```elixir
config :pleroma, Pleroma.Search, module: Pleroma.Search.DatabaseSearch
```

It has no external dependencies and requires the least amount of disk usage.
However, it is slower than external providers and for performance reasons
is limited to sorting results by recency alone instead of match quality.
Result quality may depend on how well your FTS config (typically a language)
matches the posts on your server.

Also keep in mind to make use of PostgreSQL’s websearch syntax. Full documentation can be found 
[here](https://www.postgresql.org/docs/current/textsearch-controls.html#TEXTSEARCH-PARSING-QUERIES).

In short, searching for `apple pie` will match everything containing those two words in any order or place of the text.
`"apple pie"` only matches if both words appear and `pie` immediately follows `apple`.
`apple -orange` matches everything referencing apple(s) but not orange(s).
And `or` acts as an operator to be used for alternatives; for a literal word it must be quoted `"or"`.

#### Change FTS config
By default Akkoma uses the `simple` config which performs almost no normalisation (except casing)
nor removes any stop words, making it rather strict but independent of language.

You can change your config with the `database set_text_search_config` task.
See [docs on CJK search](./howto_search_cjk.md) for advanced examples.
For many languages, Postgres already has a preset built-in you can use as is; e.g.

```sh
...database set_text_search_config english
```

#### Fuzzy search
You may choose to limit the set of posts considered during a FTS search for better performance
in exchange for potentially non-deterministic and less relevant results. See documentation of
`gin_fuzzy_search_limit` in [PostgreSQL’s docs](https://www.postgresql.org/docs/17/gin.html#GIN-TIPS).
By default FTS search is exact and considers everything. To enforce a limit only for FTS queries set e.g.:

```elixir
config :pleroma, Pleroma.Search.DatabaseSearch, gin_fuzzy_search_limit: 10_000
```

#### RUM

Instead of a GIN index, the built-in database search can also use a RUM index.
The hope was to improve performance at the cost of higher disk-storage (around 3× more)
by leveraging RUM’s capability to include extra data (here timestamps for sorting)
in the index thus avoiding additional heap lookups.

However, since search queries still need to filter results down to respect visibility etc
heap lookups are still needed anyway and in practice this probably doesn’t actually help much if at all
while taking up more disk space and needing extra setup work.  
You probably don’t want to use this and if you already do, consider migrating back to GIN.

##### Enable

!!! warning
    It is recommended to use PostgreSQL v11 or newer. We have seen some minor issues with lower PostgreSQL versions.

RUM indexes are a third-party PostgreSQL extension.
First install it via your distro if available or manually from source: https://github.com/postgrespro/rum.

Then change your Akkoma config to set:
```elixir
config :pleroma, :database, rum_enabled: true
```

To enable them, both the `rum_enabled` flag has to be set and the following special migration has to be run:

Finally run the special RUM migrations:

```sh
mix ecto.migrate --migrations-path priv/repo/optional_migrations/rum_indexing/
```

This will probably take a long time.

##### Disable
Just delete the config setting again and revert RUM-specific migrations with

```sh
mix ecto.rollback --all --migrations-path priv/repo/optional_migrations/rum_indexing/
```

Then reapply any potential regular GIN versions of the reverted migrations:

```sh
mix ecto.migrate
```

You can now remove the extension again.


### Meilisearch

Note that it's quite a bit more memory hungry than PostgreSQL (around 4-5GB for ~1.2 million
posts while idle and up to 7GB while indexing initially). It also requires significantly more
disk space (around 4GB for the previous example setup).  
This however allows it to process individually queries faster while also sorting results
by match quality ("relevancy") rather than just by recency.
Additionally, the search profits from Meilisearch’s typo tolerance etc;
see: [Meilisearch’s documentation](https://www.meilisearch.com/docs/capabilities/full_text_search/overview).

Due to high memory usage, it may be best to set it up on a different machine, if running Akkoma on a low-resource
computer, and use private key authentication to secure the remote search instance.

To use [meilisearch](https://www.meilisearch.com/), set the search module to `Pleroma.Search.Meilisearch`:

```elixir
config :pleroma, Pleroma.Search, module: Pleroma.Search.Meilisearch
```

You then need to set the address of the meilisearch instance, and optionally the private key for authentication. You might
also want to change the `initial_indexing_chunk_size` to be smaller if your server is not very powerful, but not higher than `100_000`,
because Meilisearch will refuse to process it if it's too big. However, in general you want this to be as big as possible, because Meilisearch
indexes faster when it can process many posts in a single batch.

```elixir
config :pleroma, Pleroma.Search.Meilisearch,
  url: "http://127.0.0.1:7700/",
  private_key: "private key",
  search_key: "search key",
  initial_indexing_chunk_size: 100_000
```

Information about setting up Meilisearch can be found in the
[official documentation](https://docs.meilisearch.com/learn/getting_started/installation.html).
You probably want to start it with `MEILI_NO_ANALYTICS=true` environment variable to disable analytics.
At least version 0.25.0 is required, but you are strongly advised to use at least 0.26.0, as it introduces
the `--enable-auto-batching` option which drastically improves performance. Without this option, the search
is hardly usable on a somewhat big instance.

#### Private key authentication (optional)

To set the private key, use the `MEILI_MASTER_KEY` environment variable when starting. After setting the _master key_,
you have to get the _private key_ and possibly _search key_, which are actually used for authentication.

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch show-keys <your master key here>
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch show-keys <your master key here>
    ```

You will see a "Default Admin API Key", this is the key you actually put into
your configuration file as `private_key`. You should also see a
"Default Search API key", put this into your config as `search_key`.
If your version of Meilisearch only showed the former,
just leave `search_key` completely unset in Akkoma's config.

#### Initial indexing

After setting up the configuration, you'll want to index all of your already existing posts. Only public posts are indexed.  You'll only
have to do it one time, but it might take a while, depending on the amount of posts your instance has seen. This is also a fairly RAM
consuming process for `meilisearch`, and it will take a lot of RAM when running if you have a lot of posts (seems to be around 5G for ~1.2
million posts while idle and up to 7G while indexing initially, but your experience may be different).

The sequence of actions is as follows:

1. First, change the configuration to use `Pleroma.Search.Meilisearch` as the search backend
2. Restart your instance, at this point it can be used while the search indexing is running, though search won't return anything
3. Start the initial indexing process (as described below with `index`),
   and wait until the task says it sent everything from the database to index
4. Wait until everything is actually indexed (by checking with `stats` as described below),
   at this point you don't have to do anything, just wait a while.

To start the initial indexing, run the `index` command:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch index
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch index
    ```

This will show you the total amount of posts to index, and then show you the amount of posts indexed currently, until the numbers eventually
become the same. The posts are indexed in big batches and Meilisearch will take some time to actually index them, even after you have
inserted all the posts into it. Depending on the amount of posts, this may be as long as several hours. To get information about the status
of indexing and how many posts have actually been indexed, use the `stats` command:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch stats
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch stats
    ```

#### Clearing the index

In case you need to clear the index (for example, to re-index from scratch, if that needs to happen for some reason), you can
use the `clear` command:

=== "OTP"
    ```sh
    ./bin/pleroma_ctl search.meilisearch clear
    ```

=== "From Source"
    ```sh
    mix pleroma.search.meilisearch clear
    ```

This will clear **all** the posts from the search index. Note, that deleted posts are also removed from index by the instance itself, so
there is no need to actually clear the whole index, unless you want **all** of it gone. That said, the index does not hold any information
that cannot be re-created from the database, it should also generally be a lot smaller than the size of your database. Still, the size
depends on the amount of text in posts.

### Elasticsearch

**Note: This requires at least ElasticSearch 7**

As with Meilisearch, this can be rather memory-hungry, but it is very good at what it does.

To use [Elasticsearch](https://www.elastic.co/), set the search module to `Pleroma.Search.Elasticsearch`:

```elixir
config :pleroma, Pleroma.Search, module: Pleroma.Search.Elasticsearch
```

You then need to set the URL and authentication credentials if relevant.

```elixir
config :pleroma, Pleroma.Search.Elasticsearch.Cluster,
  url: "http://127.0.0.1:9200/",
  username: "elastic",
  password: "changeme"
```

#### Initial indexing

After setting up the configuration, you'll want to index all of your already existing posts. You'll only have to do it one time, but it might take a while, depending on the amount of posts your instance has seen.

The sequence of actions is as follows:

1. First, change the configuration to use `Pleroma.Search.Elasticsearch` as the search backend
2. Restart your instance, at this point it can be used while the search indexing is running, though search won't return anything
3. Start the initial indexing process (as described below with `index`),
   and wait until the task says it sent everything from the database to index
4. Wait until the index tasks exits

To start the initial indexing, run the `build` command:

=== "OTP"
```sh
./bin/pleroma_ctl search import activities
```

=== "From Source"
```sh
mix pleroma.search import activities
```
