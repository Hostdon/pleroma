defmodule Mix.Tasks.Pleroma.Benchmarks.Tags do
  use Mix.Task

  import Pleroma.LoadTesting.Helper, only: [clean_tables: 0]
  import Ecto.Query

  alias Pleroma.Repo

  def run(_args) do
    Mix.Pleroma.start_pleroma()
    activities_count = Repo.aggregate(from(a in Pleroma.Activity), :count, :id)

    if activities_count == 0 do
      IO.puts("Did not find any activities, cleaning and generating")
      clean_tables()
      Pleroma.LoadTesting.Users.generate_users(10)
      Pleroma.LoadTesting.Activities.generate_tagged_activities()
    else
      IO.puts("Found #{activities_count} activities, won't generate new ones")
    end

    tags = Enum.map(0..20, fn i -> {"For #tag_#{i}", "tag_#{i}"} end)

    Enum.each(tags, fn {_, tag} ->
      query =
        from(o in Pleroma.Object,
          where: fragment("(?)->'tag' \\? (?)", o.data, ^tag)
        )

      count = Repo.aggregate(query, :count, :id)
      IO.puts("Database contains #{count} posts tagged with #{tag}")
    end)

    user = Repo.all(Pleroma.User) |> List.first()

    Benchee.run(
      %{
        "Hashtag fetching, any" => fn tags ->
          hashtag_fetching(
            %{
              "any" => tags
            },
            user,
            false
          )
        end,
        # Will always return zero results because no overlapping hashtags are generated.
        "Hashtag fetching, all" => fn tags ->
          hashtag_fetching(
            %{
              "all" => tags
            },
            user,
            false
          )
        end
      },
      inputs:
        tags
        |> Enum.map(fn {_, v} -> v end)
        |> Enum.chunk_every(2)
        |> Enum.map(fn tags -> {"For #{inspect(tags)}", tags} end),
      time: 5
    )

    Benchee.run(
      %{
        "Hashtag fetching" => fn tag ->
          hashtag_fetching(
            %{
              "tag" => tag
            },
            user,
            false
          )
        end
      },
      inputs: tags,
      time: 5
    )
  end

  defp hashtag_fetching(params, user, local_only) do
    tags =
      [params["tag"], params["any"]]
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.filter(& &1)
      |> Enum.map(&String.downcase(&1))

    tag_all =
      params
      |> Map.get("all", [])
      |> Enum.map(&String.downcase(&1))

    tag_reject =
      params
      |> Map.get("none", [])
      |> Enum.map(&String.downcase(&1))

    _activities =
      %{
        type: "Create",
        local_only: local_only,
        blocking_user: user,
        muting_user: user,
        user: user,
        tag: tags,
        tag_all: tag_all,
        tag_reject: tag_reject,
      }
      |> Pleroma.Web.ActivityPub.ActivityPub.fetch_public_activities()
  end
end
