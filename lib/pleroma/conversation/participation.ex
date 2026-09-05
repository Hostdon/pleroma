# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Conversation.Participation do
  use Ecto.Schema
  alias Pleroma.Conversation
  alias Pleroma.Conversation.Participation.RecipientShip
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  import Ecto.Changeset
  import Ecto.Query

  @type t() :: %__MODULE__{}

  schema "conversation_participations" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    belongs_to(:conversation, Conversation)
    field(:last_bump, FlakeId.Ecto.CompatType)
    field(:read, :boolean, default: false)
    field(:last_activity_id, FlakeId.Ecto.CompatType, virtual: true)

    has_many(:recipient_ships, RecipientShip)
    has_many(:recipients, through: [:recipient_ships, :user])

    timestamps()
  end

  defp creation_cng(struct, params) do
    struct
    |> cast(params, [:user_id, :conversation_id, :last_bump, :read])
    |> validate_required([:user_id, :conversation_id, :last_bump])
  end

  def create_or_bump(user, conversation, status_id, opts \\ []) do
    read = !!opts[:read]
    invisible_conversation = !!opts[:invisible_conversation]

    update_on_conflict =
      if(invisible_conversation, do: [], else: [read: read])
      |> Keyword.put(:updated_at, NaiveDateTime.utc_now())
      |> Keyword.put(:last_bump, status_id)

    %__MODULE__{}
    |> creation_cng(%{
      user_id: user.id,
      conversation_id: conversation.id,
      last_bump: status_id,
      read: invisible_conversation || read
    })
    |> Repo.insert(
      on_conflict: [set: update_on_conflict],
      returning: true,
      conflict_target: [:user_id, :conversation_id]
    )
  end

  defp read_cng(struct, params) do
    struct
    |> cast(params, [:read])
    |> validate_required([:read])
  end

  def mark_as_read(%User{} = user, %Conversation{} = conversation) do
    with %__MODULE__{} = participation <- for_user_and_conversation(user, conversation) do
      mark_as_read(participation)
    end
  end

  def mark_as_read(%__MODULE__{} = participation) do
    participation
    |> change(read: true)
    |> Repo.update()
  end

  def mark_all_as_read(%User{local: true} = user, %User{} = target_user) do
    target_conversation_ids =
      __MODULE__
      |> where([p], p.user_id == ^target_user.id)
      |> select([p], p.conversation_id)
      |> Repo.all()

    __MODULE__
    |> where([p], p.user_id == ^user.id)
    |> where([p], p.conversation_id in ^target_conversation_ids)
    |> update([p], set: [read: true])
    |> Repo.update_all([])

    {:ok, user, []}
  end

  def mark_all_as_read(%User{} = user, %User{}), do: {:ok, user, []}

  def mark_all_as_read(%User{} = user) do
    {_, participations} =
      __MODULE__
      |> where([p], p.user_id == ^user.id)
      |> where([p], not p.read)
      |> update([p], set: [read: true])
      |> select([p], p)
      |> Repo.update_all([])

    {:ok, user, participations}
  end

  # used for tests
  def mark_as_unread(participation) do
    participation
    |> read_cng(%{read: false})
    |> Repo.update()
  end

  def for_user_with_pagination(user, params \\ %{}) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id,
      preload: [:conversation]
    )
    |> restrict_recipients(user, params)
    |> select([p], %{id: p.last_bump, entry: p})
    |> Pleroma.Pagination.fetch_paginated(Map.put(params, :pagination_field, :last_bump))
  end

  def preload_last_activity_id_and_filter(participations) when is_list(participations) do
    participations
    |> Enum.map(fn p -> load_last_activity_id(p) end)
    |> Enum.filter(fn p -> p.last_activity_id end)
  end

  defp load_last_activity_id(%__MODULE__{} = participation) do
    %{
      participation
      | last_activity_id: last_activity_id(participation)
    }
  end

  @spec last_activity_id(t(), User.t() | nil) :: Flake.t()
  def last_activity_id(participation, user \\ nil)

  def last_activity_id(
        %__MODULE__{conversation: %Conversation{}} = participation,
        user
      ) do
    user =
      if user && user.id == participation.user_id do
        user
      else
        case participation.user do
          %User{} -> participation.user
          _ -> User.get_cached_by_id(participation.user_id)
        end
      end

    ActivityPub.fetch_latest_direct_activity_id_for_context(
      participation.conversation.ap_id,
      user
    )
  end

  def last_activity_id(%__MODULE__{} = participation, user) do
    case Repo.preload(participation, :conversation) do
      %{conversation: %Conversation{}} = p -> last_activity_id(p, user)
      _ -> nil
    end
  end

  defp restrict_recipients(query, user, %{recipients: user_ids}) do
    user_binary_ids =
      [user.id | user_ids]
      |> Enum.uniq()
      |> User.binary_id()

    recipient_subquery =
      RecipientShip
      |> group_by([r], r.participation_id)
      |> having(
        [r],
        count(r.user_id) == ^length(user_binary_ids) and
          fragment("array_agg(?) @> ?", r.user_id, ^user_binary_ids)
      )
      |> select([r], %{pid: r.participation_id})

    query
    |> join(:inner, [p], r in subquery(recipient_subquery), on: p.id == r.pid)
  end

  defp restrict_recipients(query, _, _), do: query

  def for_user_and_conversation(user, conversation) do
    from(p in __MODULE__,
      where: p.user_id == ^user.id,
      where: p.conversation_id == ^conversation.id
    )
    |> Repo.one()
  end

  def get(_, _ \\ [])
  def get(nil, _), do: nil

  def get(id, params) do
    query =
      if preload = params[:preload] do
        from(p in __MODULE__,
          preload: ^preload
        )
      else
        __MODULE__
      end

    Repo.get(query, id)
  end

  def set_recipients(participation, user_ids) do
    user_ids =
      [participation.user_id | user_ids]
      |> Enum.uniq()

    Repo.transaction(fn ->
      query =
        from(r in RecipientShip,
          where: r.participation_id == ^participation.id
        )

      Repo.delete_all(query)

      users =
        from(u in User,
          where: u.id in ^user_ids
        )
        |> Repo.all()

      RecipientShip.create(users, participation)
      :ok
    end)

    {:ok, Repo.preload(participation, :recipients, force: true)}
  end

  @spec unread_count(User.t()) :: integer()
  def unread_count(%User{id: user_id}) do
    from(q in __MODULE__, where: q.user_id == ^user_id and q.read == false)
    |> Repo.aggregate(:count, :id)
  end

  def delete(%__MODULE__{} = participation) do
    Repo.delete(participation)
  end
end
