defmodule Pleroma.Repo.Migrations.UserLocalOutboxFix do
  use Ecto.Migration

  import Ecto.Query

  # Fixing copy-paste mistake in 057d977f5af88584f48209e1acbf995995f8e54a
  def up() do
    from(
      u in Pleroma.User,
      where: u.local and like(u.outbox, "%/inbox"),
      update: [set: [outbox: fragment("regexp_replace(?, '/inbox$', '/outbox')", u.outbox)]]
    )
    |> Pleroma.Repo.update_all([])
  end

  def down() do
    # no need to revert
    :ok
  end
end
