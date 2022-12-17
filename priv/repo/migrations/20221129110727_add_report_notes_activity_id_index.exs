defmodule Pleroma.Repo.Migrations.AddReportNotesActivityIdIndex do
  use Ecto.Migration

  def change do
    create(index(:report_notes, [:activity_id]))
  end
end
