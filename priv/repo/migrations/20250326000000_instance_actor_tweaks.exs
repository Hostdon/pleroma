defmodule Pleroma.Repo.Migrations.InstanceActorsTweaks do
  use Ecto.Migration

  import Ecto.Query

  def up() do
    # since Akkoma isn’t up and running at this point, Web.endpoint()
    # isn’t available and we can't use the functions from Relay and InternalFetchActor,
    # thus the AP ID suffix are hardcoded here and used together with a check for locality
    # (e.g. custom ports make it hard to hardcode the full base url)
    relay_ap_id = "%/relay"
    fetch_ap_id = "%/internal/fetch"

    # Convert to Application type
    Pleroma.User
    |> where([u], u.local and (like(u.ap_id, ^fetch_ap_id) or like(u.ap_id, ^relay_ap_id)))
    |> Pleroma.Repo.update_all(set: [actor_type: "Application"])

    # Drop bogus follow* addresses
    Pleroma.User
    |> where([u], u.local and like(u.ap_id, ^fetch_ap_id))
    |> Pleroma.Repo.update_all(set: [follower_address: nil, following_address: nil])

    # Add required follow* addresses
    Pleroma.User
    |> where([u], u.local and like(u.ap_id, ^relay_ap_id))
    |> update([u],
      set: [
        follower_address: fragment("CONCAT(?, '/followers')", u.ap_id),
        following_address: fragment("CONCAT(?, '/following')", u.ap_id)
      ]
    )
    |> Pleroma.Repo.update_all([])
  end

  def down do
    # We don't know if the type was Person or Application before and
    # without this or the lost patch it didn't matter, so just do nothing
    :ok
  end
end
