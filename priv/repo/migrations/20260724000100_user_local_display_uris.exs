defmodule Pleroma.Repo.Migrations.UserLocalDisplayURIs do
  use Ecto.Migration

  import Ecto.Query

  def up() do
    from(
      u in Pleroma.User,
      where: u.local and is_nil(u.uri) and not is_nil(u.nickname),
      update: [set: [uri: u.ap_id]]
    )
    |> Pleroma.Repo.update_all([])
  end

  def down() do
    # no need to revert
    :ok
  end
end
