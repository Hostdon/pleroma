defmodule Pleroma.Repo.Migrations.EmojiReactDropRemotePartFromName do
  use Ecto.Migration

  import Ecto.Query

  defp drop_remote_indicator(%{"content" => emoji, "tag" => _tag} = data) do
    if String.contains?(emoji, "@") do
      do_drop_remote_indicator(data)
    else
      data
    end
  end

  defp do_drop_remote_indicator(%{"content" => emoji, "tag" => tag} = data) do
    stripped_emoji = Pleroma.Emoji.stripped_name(emoji)
    [clean_emoji | _] = String.split(stripped_emoji, "@", parts: 2)

    clean_tag =
      Enum.map(tag, fn
        %{"name" => ^stripped_emoji} = t -> %{t | "name" => clean_emoji}
        t -> t
      end)

    %{data | "content" => ":" <> clean_emoji <> ":", "tag" => clean_tag}
  end

  defp prune_and_strip_tags(%{"content" => emoji, "tag" => tags} = data) do
    clean_emoji = Pleroma.Emoji.stripped_name(emoji)

    pruned_tags =
      Enum.reduce_while(tags, [], fn
        %{"type" => "Emoji", "name" => name} = tag, res ->
          clean_name = Pleroma.Emoji.stripped_name(name)

          if clean_name == clean_emoji do
            {:halt, [%{tag | "name" => clean_name}]}
          else
            {:cont, res}
          end

        _, res ->
          {:cont, res}
      end)

    %{data | "tag" => pruned_tags}
  end

  def up() do
    has_tag_array =
      Pleroma.Activity
      |> where(
        [a],
        fragment("?->>'type' = 'EmojiReact'", a.data) and
          fragment("jsonb_typeof(?->'content') = 'string'", a.data) and
          fragment("jsonb_typeof(?->'tag') = 'array'", a.data)
      )

    from(a in subquery(has_tag_array))
    |> join(:cross_lateral, [a], fragment("jsonb_array_elements(?->'tag')", a.data))
    |> where(
      [a, t],
      fragment("?->>'content' LIKE '%@%'", a.data) or
        fragment("?->>'content' NOT LIKE ':%:'", a.data) or
        fragment("jsonb_array_length(?->'tag') > 1", a.data) or
        fragment("?->>'name' LIKE '%:%'", t) or
        fragment("?->>'name' LIKE '%@%'", t)
    )
    |> distinct(true)
    |> Pleroma.Repo.chunk_stream(600, :batches, timeout: :infinity)
    |> Stream.each(fn chunk ->
      Enum.reduce(chunk, {[], []}, fn %{id: id, data: data}, {ids, newdat} ->
        new_data =
          data
          |> prune_and_strip_tags()
          |> drop_remote_indicator()

        if new_data == data do
          {ids, newdat}
        else
          # not sure why we get a string back from the db here and need to explicit convert it back
          {[FlakeId.from_string(id) | ids], [new_data | newdat]}
        end
      end)
      |> then(fn
        {[], []} ->
          IO.puts("Nothing in current batch")
          :ok

        {ids, newdat} ->
          {upcnt, _} =
            Pleroma.Activity
            |> join(
              :inner,
              [a],
              news in fragment(
                "SELECT * FROM unnest(?::uuid[], ?::jsonb[]) AS news(id, new_data)",
                ^ids,
                ^newdat
              ),
              on: a.id == news.id
            )
            |> update([_a, news], set: [data: news.new_data])
            |> Pleroma.Repo.update_all([], timeout: :infinity)

          IO.puts("Fixed #{upcnt} reacts in current batch")
      end)
    end)
    |> Stream.run()
  end

  def down() do
    # not reversible, but also shouldn’t cause any problems
    :ok
  end
end
