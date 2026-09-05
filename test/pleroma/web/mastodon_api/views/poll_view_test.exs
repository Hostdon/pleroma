# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PollViewTest do
  use Pleroma.DataCase

  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.PollView

  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "renders a poll" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Is Tenshi eating a corndog cute?",
        poll: %{
          options: ["absolutely!", "sure", "yes", "why are you even asking?"],
          expires_in: 20
        }
      })

    object = Object.normalize(activity, fetch: false)

    expected = %{
      emojis: [],
      expired: false,
      id: to_string(object.id),
      multiple: false,
      options: [
        %{title: "absolutely!", votes_count: 0},
        %{title: "sure", votes_count: 0},
        %{title: "yes", votes_count: 0},
        %{title: "why are you even asking?", votes_count: 0}
      ],
      votes_count: 0,
      voters_count: nil,
      akkoma: %{
        # locally created polls are always anonymous
        anonymous: true
      }
    }

    result = PollView.render("show.json", %{object: object})
    expires_at = result.expires_at
    result = Map.delete(result, :expires_at)

    assert result == expected

    expires_at = NaiveDateTime.from_iso8601!(expires_at)
    assert NaiveDateTime.diff(expires_at, NaiveDateTime.utc_now()) in 15..20
  end

  test "detects if it is multiple choice" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Which Mastodon developer is your favourite?",
        poll: %{
          options: ["Gargron", "Eugen"],
          expires_in: 20,
          multiple: true
        }
      })

    voter = insert(:user)

    object = Object.normalize(activity, fetch: false)

    {:ok, _votes, object} = CommonAPI.vote(voter, object, [0, 1])

    assert match?(
             %{
               multiple: true,
               voters_count: 1,
               votes_count: 2
             },
             PollView.render("show.json", %{object: object})
           )
  end

  test "detects emoji" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "What's with the smug face?",
        poll: %{
          options: [":blank: sip", ":blank::blank: sip", ":blank::blank::blank: sip"],
          expires_in: 20
        }
      })

    object = Object.normalize(activity, fetch: false)

    assert %{emojis: [%{shortcode: "blank"}]} = PollView.render("show.json", %{object: object})
  end

  test "detects vote status" do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Which input devices do you use?",
        poll: %{
          options: ["mouse", "trackball", "trackpoint"],
          multiple: true,
          expires_in: 20
        }
      })

    object = Object.normalize(activity, fetch: false)

    {:ok, _, object} = CommonAPI.vote(other_user, object, [1, 2])

    result = PollView.render("show.json", %{object: object, for: other_user})

    assert result[:voted] == true
    assert 1 in result[:own_votes]
    assert 2 in result[:own_votes]
    assert Enum.at(result[:options], 1)[:votes_count] == 1
    assert Enum.at(result[:options], 2)[:votes_count] == 1
  end

  test "does not crash on polls with no end date" do
    object = Object.normalize("https://skippers-bin.com/notes/7x9tmrp97i", fetch: true)
    result = PollView.render("show.json", %{object: object})

    assert result[:expires_at] == nil
    assert result[:expired] == false
  end

  test "does not make false claims in absence of vote anonymity information" do
    object = Object.normalize("https://skippers-bin.com/notes/7x9tmrp97i", fetch: true)
    result = PollView.render("show.json", %{object: object})

    assert result[:akkoma][:anonymous] == nil
  end

  test "indicates promise of anonymity" do
    object = Object.normalize("https://smithereen.example/posts/poll-anon", fetch: true)
    result = PollView.render("show.json", %{object: object})

    assert result[:akkoma][:anonymous] == true
  end

  test "indicates assured vote and identity disclosure" do
    object = Object.normalize("https://smithereen.example/posts/poll-disclosed", fetch: true)
    result = PollView.render("show.json", %{object: object})

    assert result[:akkoma][:anonymous] == false
  end

  test "doesn't strips HTML tags" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "What's with the smug face?",
        poll: %{
          options: [
            "<input type=\"date\">",
            "<input type=\"date\" >",
            "<input type=\"date\"/>",
            "<input type=\"date\"></input>"
          ],
          expires_in: 20
        }
      })

    object = Object.normalize(activity, fetch: false)

    assert %{
             options: [
               %{title: "<input type=\"date\">", votes_count: 0},
               %{title: "<input type=\"date\" >", votes_count: 0},
               %{title: "<input type=\"date\"/>", votes_count: 0},
               %{title: "<input type=\"date\"></input>", votes_count: 0}
             ]
           } = PollView.render("show.json", %{object: object})
  end

  test "prefers votersCount over voters list when both are present" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Which flavor?",
        poll: %{options: ["chocolate", "vanilla"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    voter = insert(:user)
    {:ok, _, object} = CommonAPI.vote(voter, object, [0])

    assert object.data["votersCount"] == 1
    assert length(object.data["voters"]) == 1

    object = %{
      object
      | data: Map.put(object.data, "votersCount", 42)
    }

    result = PollView.render("show.json", %{object: object})

    assert result[:voters_count] == 42
  end

  test "falls back to voters list when votersCount is absent" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Which flavor?",
        poll: %{options: ["chocolate", "vanilla"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    voter = insert(:user)
    {:ok, _, object} = CommonAPI.vote(voter, object, [0])

    assert length(object.data["voters"]) == 1

    data = Map.delete(object.data, "votersCount")
    object = %{object | data: data}

    result = PollView.render("show.json", %{object: object})

    assert result[:voters_count] == 1
  end

  test "returns 0 when both votersCount and voters are absent" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Which flavor?",
        poll: %{options: ["chocolate", "vanilla"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    data =
      object.data
      |> Map.delete("votersCount")
      |> Map.delete("voters")

    object = %{object | data: data}

    result = PollView.render("show.json", %{object: object})

    assert result[:voters_count] == 0
  end

  test "returns 0 when voters list is empty" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Which flavor?",
        poll: %{options: ["chocolate", "vanilla"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    data =
      object.data
      |> Map.delete("votersCount")
      |> Map.put("voters", [])

    object = %{object | data: data}

    result = PollView.render("show.json", %{object: object})

    assert result[:voters_count] == 0
  end

  test "does not inflate votersCount when same voter picks multiple options" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Pick several",
        poll: %{options: ["a", "b", "c"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    voter = insert(:user)
    {:ok, _, object} = CommonAPI.vote(voter, object, [0, 2])

    assert object.data["votersCount"] == 1
    assert length(object.data["voters"]) == 1

    result = PollView.render("show.json", %{object: object})
    option_result = result[:options]

    assert result[:votes_count] == 2
    assert result[:voters_count] == 1
    assert Enum.find(option_result, fn %{title: t} -> t == "a" end)[:votes_count] == 1
    assert Enum.find(option_result, fn %{title: t} -> t == "b" end)[:votes_count] == 0
    assert Enum.find(option_result, fn %{title: t} -> t == "c" end)[:votes_count] == 1
  end

  test "honours pre-existing votersCount" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Pick several",
        poll: %{options: ["a", "b"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    chg = Ecto.Changeset.change(object, data: Map.put(object.data, "votersCount", 13))
    {:ok, object} = Repo.update(chg)

    voter = insert(:user)
    {:ok, _, object} = CommonAPI.vote(voter, object, [0, 1])

    result = PollView.render("show.json", %{object: object})

    assert result[:voters_count] == 14
  end

  test "returns 0 when votersCount is explicitly 0" do
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "Pick one",
        poll: %{options: ["a", "b"], expires_in: 20, multiple: true}
      })

    object = Object.normalize(activity, fetch: false)

    object = %{object | data: Map.put(object.data, "votersCount", 0)}

    result = PollView.render("show.json", %{object: object})

    assert result[:voters_count] == 0
  end
end
