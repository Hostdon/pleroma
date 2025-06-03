defmodule Pleroma.Repo.Migrations.CreateActivitiesInReplyToIndex do
  use Ecto.Migration

  def change do
    create(index(:activities, ["(data->'object'->>'inReplyTo')"], name: :activities_in_reply_to))
  end
end
