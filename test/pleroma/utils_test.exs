# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.UtilsTest do
  use ExUnit.Case, async: true

  describe "tmp_dir/1" do
    test "returns unique temporary directory" do
      {:ok, path} = Pleroma.Utils.tmp_dir("emoji")
      assert path =~ ~r/\/emoji-(.*)-#{:os.getpid()}-(.*)/
      File.rm_rf(path)
    end
  end

  describe "compile_dir/1" do
    test "recursively compiles directories" do
      {:ok, [DynamicModule.First, DynamicModule.Second], []} =
        Pleroma.Utils.compile_dir("test/fixtures/runtime_modules")
    end
  end
end
