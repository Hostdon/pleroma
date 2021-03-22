# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.DeleteValidator do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.EctoType.ActivityPub.ObjectValidators

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:actor, ObjectValidators.ObjectID)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
    field(:deleted_activity_id, ObjectValidators.ObjectID)
    field(:object, ObjectValidators.ObjectID)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  def add_deleted_activity_id(cng) do
    object =
      cng
      |> get_field(:object)

    with %Activity{id: id} <- Activity.get_create_by_object_ap_id(object) do
      cng
      |> put_change(:deleted_activity_id, id)
    else
      _ -> cng
    end
  end

  @deletable_types ~w{
    Answer
    Article
    Audio
    ChatMessage
    Event
    Note
    Page
    Question
    Tombstone
    Video
  }
  def validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Delete"])
    |> validate_actor_presence()
    |> validate_modification_rights()
    |> validate_object_or_user_presence(allowed_types: @deletable_types)
    |> add_deleted_activity_id()
  end

  def do_not_federate?(cng) do
    !same_domain?(cng)
  end

  def cast_and_validate(data) do
    data
    |> cast_data
    |> validate_data
  end
end
