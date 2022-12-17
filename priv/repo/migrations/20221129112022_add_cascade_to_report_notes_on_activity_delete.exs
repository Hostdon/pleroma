defmodule Pleroma.Repo.Migrations.AddCascadeToReportNotesOnActivityDelete do
  use Ecto.Migration

  def up do
    drop(constraint(:report_notes, "report_notes_activity_id_fkey"))

    alter table(:report_notes) do
      modify(:activity_id, references(:activities, type: :uuid, on_delete: :delete_all))
    end
  end

  def down do
    drop(constraint(:report_notes, "report_notes_activity_id_fkey"))

    alter table(:report_notes) do
      modify(:activity_id, references(:activities, type: :uuid))
    end
  end
end
