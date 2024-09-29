# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UserValidator do
  @moduledoc """
  Checks whether ActivityPub data represents a valid user

  Users don't go through the same ingest pipeline like activities or other objects.
  To ensure this can only match a user and no users match in the other pipeline,
  this is a separate from the generic ObjectValidator.
  """

  @behaviour Pleroma.Web.ActivityPub.ObjectValidator.Validating

  alias Pleroma.Object.Containment
  alias Pleroma.Signature

  require Pleroma.Constants

  @impl true
  def validate(object, meta)

  def validate(%{"type" => type, "id" => _id} = data, meta)
      when type in Pleroma.Constants.actor_types() do
    with :ok <- validate_pubkey(data),
         :ok <- validate_inbox(data),
         :ok <- contain_collection_origin(data) do
      {:ok, data, meta}
    else
      {:error, e} -> {:error, e}
      e -> {:error, e}
    end
  end

  def validate(_, _), do: {:error, "Not a user object"}

  defp mabye_validate_owner(nil, _actor), do: :ok
  defp mabye_validate_owner(actor, actor), do: :ok
  defp mabye_validate_owner(_owner, _actor), do: :error

  defp validate_pubkey(
         %{"id" => id, "publicKey" => %{"id" => pk_id, "publicKeyPem" => _key}} = data
       )
       when id != nil do
    with {_, {:ok, kactor}} <- {:key, Signature.key_id_to_actor_id(pk_id)},
         true <- id == kactor,
         :ok <- mabye_validate_owner(Map.get(data, "owner"), id) do
      :ok
    else
      {:key, _} ->
        {:error, "Unable to determine actor id from key id"}

      false ->
        {:error, "Key id does not relate to user id"}

      _ ->
        {:error, "Actor does not own its public key"}
    end
  end

  # pubkey is optional atm
  defp validate_pubkey(_data), do: :ok

  defp validate_inbox(%{"id" => id, "inbox" => inbox}) do
    case Containment.same_origin(id, inbox) do
      :ok -> :ok
      :error -> {:error, "Inbox on different doamin"}
    end
  end

  defp validate_inbox(_), do: {:error, "No inbox"}

  defp check_field_value(%{"id" => id} = _data, value) do
    Containment.same_origin(id, value)
  end

  defp maybe_check_field(data, field) do
    with val when val != nil <- data[field],
         :ok <- check_field_value(data, val) do
      :ok
    else
      nil -> :ok
      _ -> {:error, "#{field} on different domain"}
    end
  end

  defp contain_collection_origin(data) do
    Enum.reduce(["followers", "following", "featured"], :ok, fn
      field, :ok -> maybe_check_field(data, field)
      _, error -> error
    end)
  end
end
