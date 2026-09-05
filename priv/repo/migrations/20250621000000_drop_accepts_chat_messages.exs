defmodule Pleroma.Repo.Migrations.DropAcceptsChatMessages do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove(:accepts_chat_messages)
    end
  end

  def down do
    alter table(:users) do
      add(:accepts_chat_messages, :boolean, nullable: true)
    end

    execute("update users set accepts_chat_messages = true where local = true")
  end
end
