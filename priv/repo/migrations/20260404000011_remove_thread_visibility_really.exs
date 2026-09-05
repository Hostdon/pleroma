defmodule Pleroma.Repo.Migrations.RemoveThreadVisibilityReally do
  use Ecto.Migration

  def up() do
    # Migration 20260404000010 originally had an "add_if_not_exists" in both "up" and "down" by accident
    # Make sure the column is actually removed fior anyone who already ran the original
    alter table(:users) do
      remove_if_exists(:skip_thread_containment, :boolean)
    end
  end

  def down(), do: :ok
end
