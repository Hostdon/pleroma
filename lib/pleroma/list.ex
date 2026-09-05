# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.List do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.User

  schema "lists" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:title, :string)
    field(:following, {:array, :string}, default: [])
    field(:exclusive, :boolean, default: false)

    timestamps()
  end

  def update_changeset(list, attrs \\ %{}) do
    list
    |> cast(attrs, [:title, :exclusive])
    |> validate_required([:title])
  end

  def follow_changeset(list, attrs \\ %{}) do
    list
    |> cast(attrs, [:following])
    |> validate_required([:following])
  end

  def for_user(user, _opts) do
    query =
      from(
        l in Pleroma.List,
        where: l.user_id == ^user.id,
        order_by: [desc: l.id],
        limit: 50
      )

    Repo.all(query)
  end

  def get(id, %{id: user_id} = _user) do
    query =
      from(
        l in Pleroma.List,
        where: l.id == ^id,
        where: l.user_id == ^user_id
      )

    Repo.one(query)
  end

  def get_following(%Pleroma.List{following: following} = _list) do
    q =
      from(
        u in User,
        where: u.follower_address in ^following
      )

    {:ok, Repo.all(q)}
  end

  # Get lists the activity should be streamed to.
  def get_lists_from_activity(%Activity{actor: ap_id}) do
    actor = User.get_cached_by_ap_id(ap_id)

    query =
      from(
        l in Pleroma.List,
        where: fragment("? && ?", l.following, ^[actor.follower_address])
      )

    Repo.all(query)
  end

  # Get lists to which the account belongs.
  def get_lists_account_belongs(%User{} = owner, user) do
    Pleroma.List
    |> where([l], l.user_id == ^owner.id)
    |> where([l], fragment("? = ANY(?)", ^user.follower_address, l.following))
    |> Repo.all()
  end

  def update(%Pleroma.List{} = list, params) do
    list
    |> update_changeset(params)
    |> Repo.update()
  end

  def create(params, %User{} = creator) do
    changeset = update_changeset(%Pleroma.List{user_id: creator.id}, params)

    if changeset.valid? do
      Repo.insert(changeset)
    else
      {:error, changeset}
    end
  end

  def follow(%Pleroma.List{id: id}, %User{} = followed) do
    list = Repo.get(Pleroma.List, id)
    %{following: following} = list
    update_follows(list, %{following: Enum.uniq([followed.follower_address | following])})
  end

  def unfollow(%Pleroma.List{id: id}, %User{} = unfollowed) do
    list = Repo.get(Pleroma.List, id)
    %{following: following} = list
    update_follows(list, %{following: List.delete(following, unfollowed.follower_address)})
  end

  def delete(%Pleroma.List{} = list) do
    Repo.delete(list)
  end

  def update_follows(%Pleroma.List{} = list, attrs) do
    list
    |> follow_changeset(attrs)
    |> Repo.update()
  end

  def member?(%Pleroma.List{following: following}, %User{follower_address: follower_address}) do
    Enum.member?(following, follower_address)
  end

  def member?(_, _), do: false

  def get_exclusive_list_members(%User{id: user_id}) do
    Pleroma.List
    |> where([l], l.user_id == ^user_id)
    |> where([l], l.exclusive == true)
    |> join(:cross_lateral, [l], fragment("UNNEST(?)", l.following))
    |> select([_l, r], fragment("?", r))
    |> distinct(true)
    |> Repo.all()
  end
end
