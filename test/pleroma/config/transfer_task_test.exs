# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.TransferTaskTest do
  use Pleroma.DataCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  alias Pleroma.Config.TransferTask

  setup do
    clear_config(:configurable_from_database, true)
  end

  test "transfer config values from db to env" do
    refute Application.get_env(:pleroma, :test_key)
    refute Application.get_env(:idna, :test_key)
    refute Application.get_env(:quack, :test_key)
    refute Application.get_env(:postgrex, :test_key)

    initial = Application.get_env(:logger, :level)

    insert(:config, key: :test_key, value: [live: 2, com: 3])
    insert(:config, group: :idna, key: :test_key, value: [live: 15, com: 35])
    insert(:config, group: :quack, key: :test_key, value: [:test_value1, :test_value2])
    insert(:config, group: :postgrex, key: :test_key, value: :value)
    insert(:config, group: :logger, key: :level, value: :debug)
    insert(:config, group: :pleroma, key: :instance, value: [static_dir: "static_dir_from_db"])
    TransferTask.start_link([])

    assert Application.get_env(:pleroma, :test_key) == [live: 2, com: 3]
    assert Application.get_env(:idna, :test_key) == [live: 15, com: 35]
    assert Application.get_env(:quack, :test_key) == [:test_value1, :test_value2]
    assert Application.get_env(:logger, :level) == :debug
    assert Application.get_env(:postgrex, :test_key) == :value
    assert Application.get_env(:pleroma, :instance)[:static_dir] == "static_dir_from_db"

    on_exit(fn ->
      Application.delete_env(:pleroma, :test_key)
      Application.delete_env(:idna, :test_key)
      Application.delete_env(:quack, :test_key)
      Application.delete_env(:postgrex, :test_key)
      Application.put_env(:logger, :level, initial)
      System.delete_env("RELEASE_NAME")
    end)
  end

  test "transfer task falls back to env before default" do
    instance = Application.get_env(:pleroma, :instance)

    insert(:config, key: :instance, value: [name: "wow"])
    clear_config([:instance, :static_dir], "static_dir_from_env")
    TransferTask.start_link([])

    assert Application.get_env(:pleroma, :instance)[:name] == "wow"
    assert Application.get_env(:pleroma, :instance)[:static_dir] == "static_dir_from_env"

    on_exit(fn ->
      Application.put_env(:pleroma, :instance, instance)
    end)
  end

  test "transfer task falls back to release defaults if no other values found" do
    instance = Application.get_env(:pleroma, :instance)

    System.put_env("RELEASE_NAME", "akkoma")
    Pleroma.Config.Holder.save_default()
    insert(:config, key: :instance, value: [name: "wow"])
    Application.delete_env(:pleroma, :instance)

    TransferTask.start_link([])

    assert Application.get_env(:pleroma, :instance)[:name] == "wow"
    assert Application.get_env(:pleroma, :instance)[:static_dir] == "/var/lib/akkoma/static"

    on_exit(fn ->
      System.delete_env("RELEASE_NAME")
      Pleroma.Config.Holder.save_default()
      Application.put_env(:pleroma, :instance, instance)
    end)
  end

  test "transfer config values for 1 group and some keys" do
    level = Application.get_env(:quack, :level)
    meta = Application.get_env(:quack, :meta)

    insert(:config, group: :quack, key: :level, value: :info)
    insert(:config, group: :quack, key: :meta, value: [:none])

    TransferTask.start_link([])

    assert Application.get_env(:quack, :level) == :info
    assert Application.get_env(:quack, :meta) == [:none]
    default = Pleroma.Config.Holder.default_config(:quack, :webhook_url)
    assert Application.get_env(:quack, :webhook_url) == default

    on_exit(fn ->
      Application.put_env(:quack, :level, level)
      Application.put_env(:quack, :meta, meta)
    end)
  end

  test "transfer config values with full subkey update" do
    clear_config(:emoji)
    clear_config(:assets)

    insert(:config, key: :emoji, value: [groups: [a: 1, b: 2]])
    insert(:config, key: :assets, value: [mascots: [a: 1, b: 2]])

    TransferTask.start_link([])

    emoji_env = Application.get_env(:pleroma, :emoji)
    assert emoji_env[:groups] == [a: 1, b: 2]
    assets_env = Application.get_env(:pleroma, :assets)
    assert assets_env[:mascots] == [a: 1, b: 2]
  end

  describe "pleroma restart" do
    setup do
      on_exit(fn ->
        Restarter.Pleroma.refresh()

        # Restarter.Pleroma.refresh/0 is an asynchronous call.
        # A GenServer will first finish the previous call before starting a new one.
        # Here we do a synchronous call.
        # That way we are sure that the previous call has finished before we continue.
        # See https://stackoverflow.com/questions/51361856/how-to-use-task-await-with-genserver
        Restarter.Pleroma.rebooted?()
      end)
    end

    test "don't restart if no reboot time settings were changed" do
      clear_config(:emoji)
      insert(:config, key: :emoji, value: [groups: [a: 1, b: 2]])

      refute String.contains?(
               capture_log(fn ->
                 TransferTask.start_link([])

                 # TransferTask.start_link/1 is an asynchronous call.
                 # A GenServer will first finish the previous call before starting a new one.
                 # Here we do a synchronous call.
                 # That way we are sure that the previous call has finished before we continue.
                 Restarter.Pleroma.rebooted?()
               end),
               "pleroma restarted"
             )
    end

    test "on reboot time key" do
      clear_config(:rate_limit)
      insert(:config, key: :rate_limit, value: [enabled: false])

      # Note that we don't actually restart Pleroma.
      # See module Restarter.Pleroma
      assert capture_log(fn ->
               TransferTask.start_link([])

               # TransferTask.start_link/1 is an asynchronous call.
               # A GenServer will first finish the previous call before starting a new one.
               # Here we do a synchronous call.
               # That way we are sure that the previous call has finished before we continue.
               Restarter.Pleroma.rebooted?()
             end) =~ "pleroma restarted"
    end

    test "on reboot time subkey" do
      clear_config(Pleroma.Captcha)
      insert(:config, key: Pleroma.Captcha, value: [seconds_valid: 60])

      # Note that we don't actually restart Pleroma.
      # See module Restarter.Pleroma
      assert capture_log(fn ->
               TransferTask.start_link([])

               # TransferTask.start_link/1 is an asynchronous call.
               # A GenServer will first finish the previous call before starting a new one.
               # Here we do a synchronous call.
               # That way we are sure that the previous call has finished before we continue.
               Restarter.Pleroma.rebooted?()
             end) =~ "pleroma restarted"
    end

    test "don't restart pleroma on reboot time key and subkey if there is false flag" do
      clear_config(:rate_limit)
      clear_config(Pleroma.Captcha)

      insert(:config, key: :rate_limit, value: [enabled: false])
      insert(:config, key: Pleroma.Captcha, value: [seconds_valid: 60])

      refute String.contains?(
               capture_log(fn ->
                 TransferTask.load_and_update_env([], false)

                 # TransferTask.start_link/1 is an asynchronous call.
                 # A GenServer will first finish the previous call before starting a new one.
                 # Here we do a synchronous call.
                 # That way we are sure that the previous call has finished before we continue.
                 Restarter.Pleroma.rebooted?()
               end),
               "pleroma restarted"
             )
    end
  end
end
