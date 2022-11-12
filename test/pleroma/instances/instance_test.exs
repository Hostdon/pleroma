# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Instances.InstanceTest do
  alias Pleroma.Instances
  alias Pleroma.Instances.Instance
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.Web.CommonAPI

  use Pleroma.DataCase, async: true

  import ExUnit.CaptureLog
  import Pleroma.Factory

  setup_all do
    clear_config([:instance, :federation_reachability_timeout_days], 1)
    clear_config([:instances_nodeinfo, :enabled], true)
    clear_config([:instances_favicons, :enabled], true)
  end

  describe "set_reachable/1" do
    test "clears `unreachable_since` of existing matching Instance record having non-nil `unreachable_since`" do
      unreachable_since = NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())
      instance = insert(:instance, unreachable_since: unreachable_since)

      assert {:ok, instance} = Instance.set_reachable(instance.host)
      refute instance.unreachable_since
    end

    test "keeps nil `unreachable_since` of existing matching Instance record having nil `unreachable_since`" do
      instance = insert(:instance, unreachable_since: nil)

      assert {:ok, instance} = Instance.set_reachable(instance.host)
      refute instance.unreachable_since
    end

    test "does NOT create an Instance record in case of no existing matching record" do
      host = "domain.org"
      assert nil == Instance.set_reachable(host)

      assert [] = Repo.all(Ecto.Query.from(i in Instance))
      assert Instance.reachable?(host)
    end
  end

  describe "set_unreachable/1" do
    test "creates new record having `unreachable_since` to current time if record does not exist" do
      assert {:ok, instance} = Instance.set_unreachable("https://domain.com/path")

      instance = Repo.get(Instance, instance.id)
      assert instance.unreachable_since
      assert "domain.com" == instance.host
    end

    test "sets `unreachable_since` of existing record having nil `unreachable_since`" do
      instance = insert(:instance, unreachable_since: nil)
      refute instance.unreachable_since

      assert {:ok, _} = Instance.set_unreachable(instance.host)

      instance = Repo.get(Instance, instance.id)
      assert instance.unreachable_since
    end

    test "does NOT modify `unreachable_since` value of existing record in case it's present" do
      instance =
        insert(:instance, unreachable_since: NaiveDateTime.add(NaiveDateTime.utc_now(), -10))

      assert instance.unreachable_since
      initial_value = instance.unreachable_since

      assert {:ok, _} = Instance.set_unreachable(instance.host)

      instance = Repo.get(Instance, instance.id)
      assert initial_value == instance.unreachable_since
    end
  end

  describe "set_unreachable/2" do
    test "sets `unreachable_since` value of existing record in case it's newer than supplied value" do
      instance =
        insert(:instance, unreachable_since: NaiveDateTime.add(NaiveDateTime.utc_now(), -10))

      assert instance.unreachable_since

      past_value = NaiveDateTime.add(NaiveDateTime.utc_now(), -100)
      assert {:ok, _} = Instance.set_unreachable(instance.host, past_value)

      instance = Repo.get(Instance, instance.id)
      assert past_value == instance.unreachable_since
    end

    test "does NOT modify `unreachable_since` value of existing record in case it's equal to or older than supplied value" do
      instance =
        insert(:instance, unreachable_since: NaiveDateTime.add(NaiveDateTime.utc_now(), -10))

      assert instance.unreachable_since
      initial_value = instance.unreachable_since

      assert {:ok, _} = Instance.set_unreachable(instance.host, NaiveDateTime.utc_now())

      instance = Repo.get(Instance, instance.id)
      assert initial_value == instance.unreachable_since
    end
  end

  describe "update_metadata/1" do
    test "Scrapes favicon URLs and nodeinfo" do
      Tesla.Mock.mock(fn
        %{url: "https://favicon.example.org/"} ->
          %Tesla.Env{
            status: 200,
            body: ~s[<html><head><link rel="icon" href="/favicon.png"></head></html>]
          }

        %{url: "https://favicon.example.org/.well-known/nodeinfo"} ->
          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                links: [
                  %{
                    rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                    href: "https://favicon.example.org/nodeinfo/2.0"
                  }
                ]
              })
          }

        %{url: "https://favicon.example.org/nodeinfo/2.0"} ->
          %Tesla.Env{
            status: 200,
            body: Jason.encode!(%{version: "2.0", software: %{name: "Akkoma"}})
          }
      end)

      assert {:ok, %Instance{host: "favicon.example.org"}} =
               Instance.update_metadata(URI.parse("https://favicon.example.org/"))

      {:ok, instance} = Instance.get_cached_by_url("https://favicon.example.org/")
      assert instance.favicon == "https://favicon.example.org/favicon.png"
      assert instance.nodeinfo == %{"version" => "2.0", "software" => %{"name" => "Akkoma"}}
    end

    test "Does not retain favicons that are too long" do
      long_favicon_url =
        "https://Lorem.ipsum.dolor.sit.amet/consecteturadipiscingelit/Praesentpharetrapurusutaliquamtempus/Mauriseulaoreetarcu/atfacilisisorci/Nullamporttitor/nequesedfeugiatmollis/dolormagnaefficiturlorem/nonpretiumsapienorcieurisus/Nullamveleratsem/Maecenassedaccumsanexnam/favicon.png"

      Tesla.Mock.mock(fn
        %{url: "https://long-favicon.example.org/"} ->
          %Tesla.Env{
            status: 200,
            body:
              ~s[<html><head><link rel="icon" href="] <> long_favicon_url <> ~s["></head></html>]
          }

        %{url: "https://long-favicon.example.org/.well-known/nodeinfo"} ->
          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                links: [
                  %{
                    rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                    href: "https://long-favicon.example.org/nodeinfo/2.0"
                  }
                ]
              })
          }

        %{url: "https://long-favicon.example.org/nodeinfo/2.0"} ->
          %Tesla.Env{
            status: 200,
            body: Jason.encode!(%{version: "2.0", software: %{name: "Akkoma"}})
          }
      end)

      assert {:ok, %Instance{host: "long-favicon.example.org"}} =
               Instance.update_metadata(URI.parse("https://long-favicon.example.org/"))

      {:ok, instance} = Instance.get_cached_by_url("https://long-favicon.example.org/")
      assert instance.favicon == nil
    end

    test "Handles not getting a favicon URL properly" do
      Tesla.Mock.mock(fn
        %{url: "https://no-favicon.example.org/"} ->
          %Tesla.Env{
            status: 200,
            body: ~s[<html><head><h1>I wil look down and whisper "GNO.."</h1></head></html>]
          }

        %{url: "https://no-favicon.example.org/.well-known/nodeinfo"} ->
          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                links: [
                  %{
                    rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                    href: "https://no-favicon.example.org/nodeinfo/2.0"
                  }
                ]
              })
          }

        %{url: "https://no-favicon.example.org/nodeinfo/2.0"} ->
          %Tesla.Env{
            status: 200,
            body: Jason.encode!(%{version: "2.0", software: %{name: "Akkoma"}})
          }
      end)

      refute capture_log(fn ->
               assert {:ok, %Instance{host: "no-favicon.example.org"}} =
                        Instance.update_metadata(URI.parse("https://no-favicon.example.org/"))
             end) =~ "Instance.update_metadata(\"https://no-favicon.example.org/\") error: "
    end

    test "Doesn't scrape unreachable instances" do
      instance = insert(:instance, unreachable_since: Instances.reachability_datetime_threshold())
      url = "https://" <> instance.host

      assert {:discard, :unreachable} == Instance.update_metadata(URI.parse(url))
    end

    test "doesn't continue scraping nodeinfo if we can't find a link" do
      Tesla.Mock.mock(fn
        %{url: "https://bad-nodeinfo.example.org/"} ->
          %Tesla.Env{
            status: 200,
            body: ~s[<html><head><h1>I wil look down and whisper "GNO.."</h1></head></html>]
          }

        %{url: "https://bad-nodeinfo.example.org/.well-known/nodeinfo"} ->
          %Tesla.Env{
            status: 200,
            body: "oepsie woepsie de nodeinfo is kapotie uwu"
          }
      end)

      assert {:ok, %Instance{host: "bad-nodeinfo.example.org"}} =
               Instance.update_metadata(URI.parse("https://bad-nodeinfo.example.org/"))

      {:ok, instance} = Instance.get_cached_by_url("https://bad-nodeinfo.example.org/")
      assert instance.nodeinfo == nil
    end

    test "doesn't store bad json in the nodeinfo" do
      Tesla.Mock.mock(fn
        %{url: "https://bad-nodeinfo.example.org/"} ->
          %Tesla.Env{
            status: 200,
            body: ~s[<html><head><h1>I wil look down and whisper "GNO.."</h1></head></html>]
          }

        %{url: "https://bad-nodeinfo.example.org/.well-known/nodeinfo"} ->
          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                links: [
                  %{
                    rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                    href: "https://bad-nodeinfo.example.org/nodeinfo/2.0"
                  }
                ]
              })
          }

        %{url: "https://bad-nodeinfo.example.org/nodeinfo/2.0"} ->
          %Tesla.Env{
            status: 200,
            body: "oepsie woepsie de json might be bad uwu"
          }
      end)

      assert {:ok, %Instance{host: "bad-nodeinfo.example.org"}} =
               Instance.update_metadata(URI.parse("https://bad-nodeinfo.example.org/"))

      {:ok, instance} = Instance.get_cached_by_url("https://bad-nodeinfo.example.org/")
      assert instance.nodeinfo == nil
    end

    test "doesn't store incredibly long json nodeinfo" do
      too_long = String.duplicate("a", 50_000)

      Tesla.Mock.mock(fn
        %{url: "https://bad-nodeinfo.example.org/"} ->
          %Tesla.Env{
            status: 200,
            body: ~s[<html><head><h1>I wil look down and whisper "GNO.."</h1></head></html>]
          }

        %{url: "https://bad-nodeinfo.example.org/.well-known/nodeinfo"} ->
          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                links: [
                  %{
                    rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
                    href: "https://bad-nodeinfo.example.org/nodeinfo/2.0"
                  }
                ]
              })
          }

        %{url: "https://bad-nodeinfo.example.org/nodeinfo/2.0"} ->
          %Tesla.Env{
            status: 200,
            body: Jason.encode!(%{version: "2.0", software: %{name: too_long}})
          }
      end)

      assert {:ok, %Instance{host: "bad-nodeinfo.example.org"}} =
               Instance.update_metadata(URI.parse("https://bad-nodeinfo.example.org/"))

      {:ok, instance} = Instance.get_cached_by_url("https://bad-nodeinfo.example.org/")
      assert instance.nodeinfo == nil
    end
  end

  test "delete_users_and_activities/1 deletes remote instance users and activities" do
    [mario, luigi, _peach, wario] =
      users = [
        insert(:user, nickname: "mario@mushroom.kingdom", name: "Mario"),
        insert(:user, nickname: "luigi@mushroom.kingdom", name: "Luigi"),
        insert(:user, nickname: "peach@mushroom.kingdom", name: "Peach"),
        insert(:user, nickname: "wario@greedville.biz", name: "Wario")
      ]

    {:ok, post1} = CommonAPI.post(mario, %{status: "letsa go!"})
    {:ok, post2} = CommonAPI.post(luigi, %{status: "itsa me... luigi"})
    {:ok, post3} = CommonAPI.post(wario, %{status: "WHA-HA-HA!"})

    {:ok, job} = Instance.delete_users_and_activities("mushroom.kingdom")
    :ok = ObanHelpers.perform(job)

    [mario, luigi, peach, wario] = Repo.reload(users)

    refute mario.is_active
    refute luigi.is_active
    refute peach.is_active
    refute peach.name == "Peach"

    assert wario.is_active
    assert wario.name == "Wario"

    assert [nil, nil, %{}] = Repo.reload([post1, post2, post3])
  end
end
