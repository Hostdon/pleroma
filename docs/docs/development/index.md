# Contributing to Akkoma

You wish to add a new feature in Akkoma, but don't know how to proceed? This guide takes you through the various steps of the development and contribution process.

If you're looking for stuff to implement or fix, check the [bug-tracker](https://akkoma.dev/AkkomaGang/akkoma/issues) or [forum](https://meta.akkoma.dev/c/requests/5).

Come say hi to us in the [#akkoma-dev chat room](./../#irc)!

## Akkoma Clients

Akkoma is the back-end. Clients have their own repositories and often separate projects. You can check what clients work with Akkoma [on the clients page](../clients/). If you maintain a working client not listed yet, feel free to make a PR [to these docs](./#docs)!

For resources on APIs and such, check the sidebar of this page.

## Docs

The docs are written in Markdown, including certain extensions, and can be found [in the docs folder of the Akkoma repo](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/docs/). The content itself is stored in the `docs` subdirectory.

## Technology

Akkoma is written in [Elixir](https://elixir-lang.org/) and uses [Postgresql](https://www.postgresql.org/) for database. We use [Git](https://git-scm.com/) for collaboration and tracking code changes. Furthermore it can typically run on [Unix and Unix-like OS'es](https://en.wikipedia.org/wiki/Unix-like). For development, you should use an OS which [can run Akkoma](../installation/debian_based_en/).

It's good to have at least some basic understanding of at least Git and Elixir. If this is completely new for you, there's some [videos explaining Git](https://git-scm.com/doc) and Codeberg has a nice article explaining the typical [pull requests Git flow](https://docs.codeberg.org/collaborating/pull-requests-and-git-flow/). For Elixir, you can follow Elixir's own [Getting Started guide](https://elixir-lang.org/getting-started/introduction.html).

## Setting up a development environment

The best way to start is getting the software to run from source so you can start poking on it. Check out the [guides for setting up an Akkoma instance for development](setting_up_akkoma_dev/#setting-up-a-akkoma-development-environment).

## General overview
### Modules

Akkoma has several modules. There are modules for [uploading](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/lib/pleroma/uploaders), [upload filters](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/lib/pleroma/upload/filter), [translators](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/lib/pleroma/akkoma/translators)... The most famous ones are without a doubt the [MRF policies](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/lib/pleroma/web/activity_pub/mrf). Modules are often self contained and a good way to start with development because you don't have to think about much more than just the module itself. We even have an example on [writing your own MRF policy](/configuration/mrf/#writing-your-own-mrf-policy)!

Another easy entry point is the [mix tasks](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/lib/mix/tasks/pleroma). They too are often self contained and don't need you to go through much of the code.

### Activity Streams/Activity Pub

Akkoma uses Activity Streams for both federation, as well as internal representation. It may be interesting to at least go over the specifications of [Activity Pub](https://www.w3.org/TR/activitypub/), [Activity Streams 2.0](https://www.w3.org/TR/activitystreams-core/), and [Activity Streams Vocabulary](https://www.w3.org/TR/activitystreams-vocabulary/). Note that these are not enough to have a full grasp of how everything works, but should at least give you the basics to understand how messages are passed between and inside Akkoma instances.

## Don't forget

When you make changes, you're expected to create [a Pull Request](https://akkoma.dev/AkkomaGang/akkoma/pulls). You don't have to wait until you finish to create the PR, but please do prefix the title of the PR with "WIP: " for as long as you're still working on it. The sooner you create your PR, the sooner people know what you are working on and the sooner you can get feedback and, if needed, help. You can then simply keep working on it until you are finished.

When doing changes, don't forget to add it to the relevant parts of the [CHANGELOG.md](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/CHANGELOG.md).

You're expected to write [tests](https://elixirschool.com/en/lessons/testing/basics). While code is generally stored in the `lib` directory, tests are stored in the `test` directory using a similar folder structure. Feel free to peak at other tests to see how they are done. Obviously tests are expected to pass and properly test the functionality you added. If you feel really confident, you could even try to [write a test first and then write the code needed to make it pass](https://en.wikipedia.org/wiki/Test-driven_development)!

Code is formatted using the default formatter that comes with Elixir. You can format a file with e.g. `mix format /path/to/file.ex`. To check if everything is properly formatted, you can run `mix format --check-formatted`.
