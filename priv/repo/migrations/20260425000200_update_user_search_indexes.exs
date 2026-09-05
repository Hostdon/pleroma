defmodule Pleroma.Repo.Migrations.UpdateUserSearchIndexes do
  use Ecto.Migration

  # copied from 20190115085500_create_user_fts_index
  @old_fts_idx index(
                 :users,
                 [
                   """
                   (setweight(to_tsvector('simple', regexp_replace(nickname, '\\W', ' ', 'g')), 'A') ||
                   setweight(to_tsvector('simple', regexp_replace(coalesce(name, ''), '\\W', ' ', 'g')), 'B'))
                   """
                 ],
                 name: :users_fts_index,
                 using: :gin
               )

  @new_fts_idx index(
                 :users,
                 ["to_tsvector('simple', name)"],
                 name: :users_displayname_fts_index,
                 using: :gin
               )

  # Conceptually this _could_ replace the existing unique nickname index, since citext is case-insesensitive anyway.
  # In practice however, we need this in the first place, beacuse PostgreSQL does not provide case-insensitive starts_with for citext and
  # also couldn’t use an index with explicit LOWER() for regular nickname lookups without, eventhough it ought to be the same for a citext-typed column
  #
  # Once we raise our minimal PostgreSQL version to 18, we may want to recreate this index with CASEFOLD instead
  # (and adapt all queries to match ofc)
  @prefix_idx index(
                :users,
                [~s'LOWER(nickname)'],
                name: :users_casefolded_nickname_index,
                unique: true,
                using: :btree
              )

  def change() do
    drop_if_exists(@old_fts_idx)
    create_if_not_exists(@new_fts_idx)
    create_if_not_exists(@prefix_idx)
  end
end
