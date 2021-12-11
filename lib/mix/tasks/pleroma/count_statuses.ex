# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.CountStatuses do
  @shortdoc "Re-counts statuses for all users"

  use Mix.Task
  alias Pleroma.User
  import Ecto.Query

  def run([]) do
    Mix.Pleroma.start_pleroma()

    stream =
      User
      |> where(local: true)
      |> Pleroma.Repo.stream()

    Pleroma.Repo.transaction(fn ->
      Enum.each(stream, &User.update_note_count/1)
    end)

    Mix.Pleroma.shell_info("Done")
  end
end
