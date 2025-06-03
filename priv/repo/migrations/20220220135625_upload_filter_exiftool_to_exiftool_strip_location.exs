defmodule Pleroma.Repo.Migrations.UploadFilterExiftoolToExiftoolStripMetadata do
  use Ecto.Migration

  # 20240425120000_upload_filter_exiftool_to_exiftool_strip_location.exs
  # was originally committed with the id used in this file, but this breaks
  # rollback order. Thus it was moved to 20240425120000 and this stub just prevents
  # errors during large-scale rollbacks for anyone who already applied the old id
  def up, do: :ok
  def down, do: :ok
end
