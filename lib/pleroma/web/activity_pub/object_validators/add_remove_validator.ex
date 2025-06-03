# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AddRemoveValidator do
  use Ecto.Schema

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  require Pleroma.Constants
  require Logger

  alias Pleroma.User

  @primary_key false

  embedded_schema do
    field(:target)

    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        activity_fields()
      end
    end
  end

  def cast_and_validate(data) do
    with {_, {:ok, actor}} <- {:user, User.get_or_fetch_by_ap_id(data["actor"])},
         {_, {:ok, actor}} <- {:feataddr, maybe_refetch_user(actor)} do
      data
      |> maybe_fix_data_for_mastodon(actor)
      |> cast_data()
      |> validate_data(actor)
    else
      {:feataddr, _} ->
        {:error,
         {:validate,
          "Actor doesn't provide featured collection address to verify against: #{data["id"]}"}}

      {:user, _} ->
        {:error, :link_resolve_failed}
    end
  end

  defp maybe_fix_data_for_mastodon(data, actor) do
    # Mastodon sends pin/unpin objects without id, to, cc fields
    data
    |> Map.put_new("id", Pleroma.Web.ActivityPub.Utils.generate_activity_id())
    |> Map.put_new("to", [Pleroma.Constants.as_public()])
    |> Map.put_new("cc", [actor.follower_address])
  end

  defp cast_data(data) do
    cast(%__MODULE__{}, data, __schema__(:fields))
  end

  defp validate_data(changeset, actor) do
    changeset
    |> validate_required([:id, :target, :object, :actor, :type, :to, :cc])
    |> validate_inclusion(:type, ~w(Add Remove))
    |> validate_actor_presence()
    |> validate_collection_belongs_to_actor(actor)
    |> validate_object_presence()
  end

  defp validate_collection_belongs_to_actor(changeset, actor) do
    validate_change(changeset, :target, fn :target, target ->
      if target == actor.featured_address do
        []
      else
        [target: "collection doesn't belong to actor"]
      end
    end)
  end

  defp maybe_refetch_user(%User{featured_address: address} = user) when is_binary(address) do
    {:ok, user}
  end

  defp maybe_refetch_user(%User{ap_id: ap_id}) do
    # If the user didn't expose a featured collection before,
    # recheck now so we can verify perms for add/remove.
    # But wait at least 5s to avoid rapid refetches in edge cases
    User.get_or_fetch_by_ap_id(ap_id, maximum_age: 5)
  end
end
