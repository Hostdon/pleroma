defmodule Pleroma.Repo.Migrations.RenameIndexUsersApId_COALESCEFollowerAddressIndex do
  alias Pleroma.Repo

  use Ecto.Migration

  def up do
    # By default Postgresql first restores the data and then the indexes when dumping and restoring the database.
    # Restoring index activities_visibility_index took a very long time.
    # users_ap_id_COALESCE_follower_address_index was later added because having this could speed up the restoration tremendously.
    # The problem now is that restoration apparently happens in alphabetical order, so this new index wasn't created yet
    # by the time activities_visibility_index needed it.
    # There were several work-arounds which included more complex steps during backup/restore.
    # By renaming this index, it should be restored first and thus activities_visibility_index can make use of it.
    # This speeds up restoration significantly without requiring more complex or unexpected steps from people.
    Repo.query!("ALTER INDEX public.\"users_ap_id_COALESCE_follower_address_index\"
    RENAME TO \"aa_users_ap_id_COALESCE_follower_address_index\";")
  end

  def down do
    Repo.query!("ALTER INDEX public.\"aa_users_ap_id_COALESCE_follower_address_index\"
    RENAME TO \"users_ap_id_COALESCE_follower_address_index\";")
  end
end
