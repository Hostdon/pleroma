# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Tests.ObanHelpers do
  @moduledoc """
  Oban test helpers.
  """

  require Ecto.Query

  alias Pleroma.Repo

  def wipe_all do
    Repo.delete_all(Oban.Job)
  end

  def perform_all do
    Oban.Job
    |> Ecto.Query.where(state: "available")
    |> Repo.all()
    |> perform()
  end

  def perform(%Oban.Job{} = job) do
    res = apply(String.to_existing_atom("Elixir." <> job.worker), :perform, [job])
    Repo.delete(job)
    res
  end

  def perform(jobs) when is_list(jobs) do
    for job <- jobs, do: perform(job)
  end

  def member?(%{} = job_args, jobs) when is_list(jobs) do
    Enum.any?(jobs, fn job ->
      member?(job_args, job.args)
    end)
  end

  def member?(%{} = test_attrs, %{} = attrs) do
    Enum.all?(
      test_attrs,
      fn {k, _v} -> member?(test_attrs[k], attrs[k]) end
    )
  end

  def member?(x, y), do: x == y
end
