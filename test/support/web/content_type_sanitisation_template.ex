# Akkoma: Magically expressive social media
# Copyright © 2025 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ContentTypeSanitisationTemplate do
  defmacro do_test(create_fun, fname, body, content_type) do
    quote do
      url = unquote(create_fun).(unquote(fname), unquote(body))
      resp = get(build_conn(), url)
      assert resp.status == 200

      assert Enum.all?(
               Plug.Conn.get_resp_header(resp, "content-type"),
               fn e -> e == unquote(content_type) end
             )
    end
  end

  defmacro do_all_common_tests(create_fun) do
    quote do
      test "while preserving image types" do
        unquote(__MODULE__).do_test(
          unquote(create_fun),
          "image.jpg",
          File.read!("test/fixtures/image.jpg"),
          "image/jpeg"
        )
      end

      test "if ActivityPub type" do
        # this already ought to be impossible from the configured MIME mapping, but let’s make sure
        unquote(__MODULE__).do_test(
          unquote(create_fun),
          "ap.activity+json",
          "{\"a\": \"b\"}",
          "application/octet-stream"
        )
      end

      test "if PDF type" do
        unquote(__MODULE__).do_test(
          unquote(create_fun),
          "pdf.pdf",
          "pdf stub",
          "application/octet-stream"
        )
      end

      test "if Javascript type" do
        unquote(__MODULE__).do_test(
          unquote(create_fun),
          "script.js",
          "alert('miaow');",
          "application/octet-stream"
        )
      end

      test "if CSS type" do
        unquote(__MODULE__).do_test(
          unquote(create_fun),
          "script.js",
          ".StatusBody {display: none;}",
          "application/octet-stream"
        )
      end
    end
  end

  defmacro do_audio_test(create_fun, sanitise \\ false) do
    quote do
      expected_type = if unquote(sanitise), do: "application/octet-stream", else: "audio/mpeg"

      unquote(__MODULE__).do_test(
        unquote(create_fun),
        "audio.mp3",
        File.read!("test/fixtures/sound.mp3"),
        expected_type
      )
    end
  end
end
