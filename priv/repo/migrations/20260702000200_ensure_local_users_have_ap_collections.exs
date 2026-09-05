defmodule Pleroma.Repo.Migrations.EnsureLocalUsersHaveAPCollections do
  use Ecto.Migration

  import Ecto.Query

  defp update_for(target, suffix) do
    from(
      u in Pleroma.User,
      where: u.local and is_nil(field(u, ^target)),
      update: [set: [{^target, fragment("? || ?::text", u.ap_id, ^suffix)}]]
    )
    |> Pleroma.Repo.update_all([])
  end

  def up() do
    # Suffixes are copied from contemporary generate_* functions in User module

    # note: up until now local users _always_ had a nil inbox and outbox
    update_for(:inbox, "/inbox")
    update_for(:outbox, "/outbox")

    update_for(:featured_address, "/collections/featured")

    update_for(:follower_address, "/followers")
    update_for(:following_address, "/following")
  end

  def down() do
    # no need to revert
    :ok
  end
end
