defmodule Pleroma.Repo.Migrations.AddUserFrontendProfiles do
  use Ecto.Migration

  def up do
    create_if_not_exists table("user_frontend_setting_profiles", primary_key: false) do
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), primary_key: true)
      add(:frontend_name, :string, primary_key: true)
      add(:profile_name, :string, primary_key: true)
      add(:version, :integer)
      add(:settings, :map)
      timestamps()
    end

    create_if_not_exists(index(:user_frontend_setting_profiles, [:user_id, :frontend_name]))

    create_if_not_exists(
      unique_index(:user_frontend_setting_profiles, [:user_id, :frontend_name, :profile_name])
    )
  end

  def down do
    drop_if_exists(table("user_frontend_setting_profiles"))
    drop_if_exists(index(:user_frontend_setting_profiles, [:user_id, :frontend_name]))

    drop_if_exists(
      unique_index(:user_frontend_setting_profiles, [:user_id, :frontend_name, :profile_name])
    )
  end
end
