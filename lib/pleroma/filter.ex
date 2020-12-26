# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Filter do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  schema "filters" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:filter_id, :integer)
    field(:hide, :boolean, default: false)
    field(:whole_word, :boolean, default: true)
    field(:phrase, :string)
    field(:context, {:array, :string})
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def get(id, %{id: user_id} = _user) do
    query =
      from(
        f in Pleroma.Filter,
        where: f.filter_id == ^id,
        where: f.user_id == ^user_id
      )

    Repo.one(query)
  end

  def get_active(query) do
    from(f in query, where: is_nil(f.expires_at) or f.expires_at > ^NaiveDateTime.utc_now())
  end

  def get_irreversible(query) do
    from(f in query, where: f.hide)
  end

  def get_filters(query \\ __MODULE__, %User{id: user_id}) do
    query =
      from(
        f in query,
        where: f.user_id == ^user_id,
        order_by: [desc: :id]
      )

    Repo.all(query)
  end

  def create(%Pleroma.Filter{user_id: user_id, filter_id: nil} = filter) do
    # If filter_id wasn't given, use the max filter_id for this user plus 1.
    # XXX This could result in a race condition if a user tries to add two
    # different filters for their account from two different clients at the
    # same time, but that should be unlikely.

    max_id_query =
      from(
        f in Pleroma.Filter,
        where: f.user_id == ^user_id,
        select: max(f.filter_id)
      )

    filter_id =
      case Repo.one(max_id_query) do
        # Start allocating from 1
        nil ->
          1

        max_id ->
          max_id + 1
      end

    filter
    |> Map.put(:filter_id, filter_id)
    |> Repo.insert()
  end

  def create(%Pleroma.Filter{} = filter) do
    Repo.insert(filter)
  end

  def delete(%Pleroma.Filter{id: filter_key} = filter) when is_number(filter_key) do
    Repo.delete(filter)
  end

  def delete(%Pleroma.Filter{id: filter_key} = filter) when is_nil(filter_key) do
    %Pleroma.Filter{id: id} = get(filter.filter_id, %{id: filter.user_id})

    filter
    |> Map.put(:id, id)
    |> Repo.delete()
  end

  def update(%Pleroma.Filter{} = filter, params) do
    filter
    |> cast(params, [:phrase, :context, :hide, :expires_at, :whole_word])
    |> validate_required([:phrase, :context])
    |> Repo.update()
  end

  def compose_regex(user_or_filters, format \\ :postgres)

  def compose_regex(%User{} = user, format) do
    __MODULE__
    |> get_active()
    |> get_irreversible()
    |> get_filters(user)
    |> compose_regex(format)
  end

  def compose_regex([_ | _] = filters, format) do
    phrases =
      filters
      |> Enum.map(& &1.phrase)
      |> Enum.join("|")

    case format do
      :postgres ->
        "\\y(#{phrases})\\y"

      :re ->
        ~r/\b#{phrases}\b/i

      _ ->
        nil
    end
  end

  def compose_regex(_, _), do: nil
end
