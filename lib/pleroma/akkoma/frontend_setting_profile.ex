defmodule Pleroma.Akkoma.FrontendSettingsProfile do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.Config
  alias Pleroma.User

  @primary_key false
  schema "user_frontend_setting_profiles" do
    belongs_to(:user, Pleroma.User, primary_key: true, type: FlakeId.Ecto.CompatType)
    field(:frontend_name, :string, primary_key: true)
    field(:profile_name, :string, primary_key: true)
    field(:settings, :map)
    field(:version, :integer)
    timestamps()
  end

  def changeset(%__MODULE__{} = struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :frontend_name, :profile_name, :settings, :version])
    |> validate_required([:user_id, :frontend_name, :profile_name, :settings, :version])
    |> validate_length(:frontend_name, min: 1, max: 255)
    |> validate_length(:profile_name, min: 1, max: 255)
    |> validate_version(struct)
    |> validate_number(:version, greater_than: 0)
    |> validate_settings_length(Config.get([:instance, :max_frontend_settings_json_chars]))
  end

  def create_or_update(%User{} = user, frontend_name, profile_name, settings, version) do
    struct =
      case get_by_user_and_frontend_name_and_profile_name(user, frontend_name, profile_name) do
        nil ->
          %__MODULE__{}

        %__MODULE__{} = profile ->
          profile
      end

    struct
    |> changeset(%{
      user_id: user.id,
      frontend_name: frontend_name,
      profile_name: profile_name,
      settings: settings,
      version: version
    })
    |> Repo.insert_or_update()
  end

  def get_all_by_user_and_frontend_name(%User{id: user_id}, frontend_name) do
    Repo.all(
      from(p in __MODULE__, where: p.user_id == ^user_id and p.frontend_name == ^frontend_name)
    )
  end

  def get_by_user_and_frontend_name_and_profile_name(
        %User{id: user_id},
        frontend_name,
        profile_name
      ) do
    Repo.one(
      from(p in __MODULE__,
        where:
          p.user_id == ^user_id and p.frontend_name == ^frontend_name and
            p.profile_name == ^profile_name
      )
    )
  end

  def delete_profile(profile) do
    Repo.delete(profile)
  end

  defp validate_settings_length(
         %Ecto.Changeset{changes: %{settings: settings}} = changeset,
         max_length
       ) do
    settings_json = Jason.encode!(settings)

    if String.length(settings_json) > max_length do
      add_error(changeset, :settings, "is too long")
    else
      changeset
    end
  end

  defp validate_version(changeset, %{version: nil}), do: changeset

  defp validate_version(%Ecto.Changeset{changes: %{version: version}} = changeset, %{
         version: prev_version
       }) do
    if version != prev_version + 1 do
      add_error(changeset, :version, "must be incremented by 1")
    else
      changeset
    end
  end
end
