# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.NewUsersDigestWorkerTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Workers.Cron.NewUsersDigestWorker

  test "it sends new users digest emails" do
    yesterday = NaiveDateTime.utc_now() |> Timex.shift(days: -1)
    admin = insert(:user, %{is_admin: true})
    user = insert(:user, %{inserted_at: yesterday})
    user2 = insert(:user, %{inserted_at: yesterday})
    CommonAPI.post(user, %{status: "cofe"})

    NewUsersDigestWorker.perform(%Oban.Job{})
    ObanHelpers.perform_all()

    assert_received {:email, email}
    assert email.to == [{admin.name, admin.email}]
    assert email.subject == "#{Pleroma.Config.get([:instance, :name])} New Users"

    refute email.html_body =~ admin.nickname
    assert email.html_body =~ user.nickname
    assert email.html_body =~ user2.nickname
    assert email.html_body =~ "cofe"
    assert email.html_body =~ "#{Pleroma.Web.Endpoint.url()}/static/logo.png"
  end

  test "it doesn't fail when admin has no email" do
    yesterday = NaiveDateTime.utc_now() |> Timex.shift(days: -1)
    insert(:user, %{is_admin: true, email: nil})
    insert(:user, %{inserted_at: yesterday})
    user = insert(:user, %{inserted_at: yesterday})

    CommonAPI.post(user, %{status: "cofe"})

    NewUsersDigestWorker.perform(%Oban.Job{})
    ObanHelpers.perform_all()
  end
end
