# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ReportView do
  use Pleroma.Web, :view

  alias Pleroma.HTML
  alias Pleroma.User
  alias Pleroma.Web.AdminAPI
  alias Pleroma.Web.AdminAPI.Report
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.StatusView

  defdelegate merge_account_views(user), to: AdminAPI.AccountView

  def render("index.json", %{reports: reports}) do
    %{
      reports:
        reports[:items]
        |> Enum.map(&Report.extract_report_info/1)
        |> Enum.map(&render(__MODULE__, "show.json", &1)),
      total: reports[:total]
    }
  end

  def render("show.json", %{report: report, user: user, account: account, statuses: statuses}) do
    created_at = Utils.to_masto_date(report.data["published"])

    content =
      unless is_nil(report.data["content"]) do
        HTML.filter_tags(report.data["content"])
      else
        nil
      end

    %{
      id: report.id,
      account: merge_account_views(account),
      actor: merge_account_views(user),
      content: content,
      created_at: created_at,
      statuses:
        StatusView.render("index.json", %{
          activities: statuses,
          as: :activity
        }),
      state: report.data["state"],
      notes: render(__MODULE__, "index_notes.json", %{notes: report.report_notes})
    }
  end

  def render("index_notes.json", %{notes: notes}) when is_list(notes) do
    Enum.map(notes, &render(__MODULE__, "show_note.json", Map.from_struct(&1)))
  end

  def render("index_notes.json", _), do: []

  def render("show_note.json", %{
        id: id,
        content: content,
        user_id: user_id,
        inserted_at: inserted_at
      }) do
    user = User.get_by_id(user_id)

    %{
      id: id,
      content: content,
      user: merge_account_views(user),
      created_at: Utils.to_masto_date(inserted_at)
    }
  end
end
