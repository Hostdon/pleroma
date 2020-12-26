# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidator do
  @moduledoc """
  This module is responsible for validating an object (which can be an activity)
  and checking if it is both well formed and also compatible with our view of
  the system.
  """

  alias Pleroma.Activity
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ObjectValidators.AcceptRejectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AnnounceValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AnswerValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.ArticleNoteValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AudioVideoValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.BlockValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.ChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateChatMessageValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.CreateGenericValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.DeleteValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.EventValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.FollowValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.UndoValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.UpdateValidator

  @spec validate(map(), keyword()) :: {:ok, map(), keyword()} | {:error, any()}
  def validate(object, meta)

  def validate(%{"type" => type} = object, meta)
      when type in ~w[Accept Reject] do
    with {:ok, object} <-
           object
           |> AcceptRejectValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Event"} = object, meta) do
    with {:ok, object} <-
           object
           |> EventValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Follow"} = object, meta) do
    with {:ok, object} <-
           object
           |> FollowValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Block"} = block_activity, meta) do
    with {:ok, block_activity} <-
           block_activity
           |> BlockValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      block_activity = stringify_keys(block_activity)
      outgoing_blocks = Pleroma.Config.get([:activitypub, :outgoing_blocks])

      meta =
        if !outgoing_blocks do
          Keyword.put(meta, :do_not_federate, true)
        else
          meta
        end

      {:ok, block_activity, meta}
    end
  end

  def validate(%{"type" => "Update"} = update_activity, meta) do
    with {:ok, update_activity} <-
           update_activity
           |> UpdateValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      update_activity = stringify_keys(update_activity)
      {:ok, update_activity, meta}
    end
  end

  def validate(%{"type" => "Undo"} = object, meta) do
    with {:ok, object} <-
           object
           |> UndoValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      undone_object = Activity.get_by_ap_id(object["object"])

      meta =
        meta
        |> Keyword.put(:object_data, undone_object.data)

      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Delete"} = object, meta) do
    with cng <- DeleteValidator.cast_and_validate(object),
         do_not_federate <- DeleteValidator.do_not_federate?(cng),
         {:ok, object} <- Ecto.Changeset.apply_action(cng, :insert) do
      object = stringify_keys(object)
      meta = Keyword.put(meta, :do_not_federate, do_not_federate)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Like"} = object, meta) do
    with {:ok, object} <-
           object
           |> LikeValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "ChatMessage"} = object, meta) do
    with {:ok, object} <-
           object
           |> ChatMessageValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Question"} = object, meta) do
    with {:ok, object} <-
           object
           |> QuestionValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => type} = object, meta) when type in ~w[Audio Video] do
    with {:ok, object} <-
           object
           |> AudioVideoValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Article"} = object, meta) do
    with {:ok, object} <-
           object
           |> ArticleNoteValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "Answer"} = object, meta) do
    with {:ok, object} <-
           object
           |> AnswerValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(%{"type" => "EmojiReact"} = object, meta) do
    with {:ok, object} <-
           object
           |> EmojiReactValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def validate(
        %{"type" => "Create", "object" => %{"type" => "ChatMessage"} = object} = create_activity,
        meta
      ) do
    with {:ok, object_data} <- cast_and_apply(object),
         meta = Keyword.put(meta, :object_data, object_data |> stringify_keys),
         {:ok, create_activity} <-
           create_activity
           |> CreateChatMessageValidator.cast_and_validate(meta)
           |> Ecto.Changeset.apply_action(:insert) do
      create_activity = stringify_keys(create_activity)
      {:ok, create_activity, meta}
    end
  end

  def validate(
        %{"type" => "Create", "object" => %{"type" => objtype} = object} = create_activity,
        meta
      )
      when objtype in ~w[Question Answer Audio Video Event Article] do
    with {:ok, object_data} <- cast_and_apply(object),
         meta = Keyword.put(meta, :object_data, object_data |> stringify_keys),
         {:ok, create_activity} <-
           create_activity
           |> CreateGenericValidator.cast_and_validate(meta)
           |> Ecto.Changeset.apply_action(:insert) do
      create_activity = stringify_keys(create_activity)
      {:ok, create_activity, meta}
    end
  end

  def validate(%{"type" => "Announce"} = object, meta) do
    with {:ok, object} <-
           object
           |> AnnounceValidator.cast_and_validate()
           |> Ecto.Changeset.apply_action(:insert) do
      object = stringify_keys(object)
      {:ok, object, meta}
    end
  end

  def cast_and_apply(%{"type" => "ChatMessage"} = object) do
    ChatMessageValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Question"} = object) do
    QuestionValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Answer"} = object) do
    AnswerValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => type} = object) when type in ~w[Audio Video] do
    AudioVideoValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Event"} = object) do
    EventValidator.cast_and_apply(object)
  end

  def cast_and_apply(%{"type" => "Article"} = object) do
    ArticleNoteValidator.cast_and_apply(object)
  end

  def cast_and_apply(o), do: {:error, {:validator_not_set, o}}

  # is_struct/1 isn't present in Elixir 1.8.x
  def stringify_keys(%{__struct__: _} = object) do
    object
    |> Map.from_struct()
    |> stringify_keys
  end

  def stringify_keys(object) when is_map(object) do
    object
    |> Map.new(fn {key, val} -> {to_string(key), stringify_keys(val)} end)
  end

  def stringify_keys(object) when is_list(object) do
    object
    |> Enum.map(&stringify_keys/1)
  end

  def stringify_keys(object), do: object

  def fetch_actor(object) do
    with actor <- Containment.get_actor(object),
         {:ok, actor} <- ObjectValidators.ObjectID.cast(actor) do
      User.get_or_fetch_by_ap_id(actor)
    end
  end

  def fetch_actor_and_object(object) do
    fetch_actor(object)
    Object.normalize(object["object"], true)
    :ok
  end
end
