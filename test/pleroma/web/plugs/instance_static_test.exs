# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.InstanceStaticTest do
  use Pleroma.Web.ConnCase

  @dir "test/tmp/instance_static"

  setup do
    File.mkdir_p!(@dir)
    on_exit(fn -> File.rm_rf(@dir) end)
  end

  setup do: clear_config([:instance, :static_dir], @dir)

  test "overrides index" do
    bundled_index = get(build_conn(), "/")
    refute html_response(bundled_index, 200) == "hello world"

    File.write!(@dir <> "/index.html", "hello world")

    index = get(build_conn(), "/")
    assert html_response(index, 200) == "hello world"
  end

  test "also overrides frontend files", %{conn: conn} do
    name = "pelmora"
    ref = "uguu"

    clear_config([:frontends, :primary], %{"name" => name, "ref" => ref})

    bundled_index = get(conn, "/")
    refute html_response(bundled_index, 200) == "from frontend plug"

    path = "#{@dir}/frontends/#{name}/#{ref}"
    File.mkdir_p!(path)
    File.write!("#{path}/index.html", "from frontend plug")

    index = get(conn, "/")
    assert html_response(index, 200) == "from frontend plug"

    File.write!(@dir <> "/index.html", "from instance static")

    index = get(conn, "/")
    assert html_response(index, 200) == "from instance static"
  end
end
