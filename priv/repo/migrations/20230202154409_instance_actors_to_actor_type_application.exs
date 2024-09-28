defmodule Pleroma.Repo.Migrations.InstanceActorsToActorTypeApplication do
  use Ecto.Migration

  def up do
    execute("""
    update users
    set actor_type = 'Application'
    where local
    and (ap_id like '%/relay' or ap_id like '%/internal/fetch')
    """)
  end

  def down do
    execute("""
    update users
    set actor_type = 'Person'
    where local
    and (ap_id like '%/relay' or ap_id like '%/internal/fetch')
    """)
  end
end
