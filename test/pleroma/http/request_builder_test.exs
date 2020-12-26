# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.RequestBuilderTest do
  use ExUnit.Case
  use Pleroma.Tests.Helpers
  alias Pleroma.HTTP.Request
  alias Pleroma.HTTP.RequestBuilder

  describe "headers/2" do
    test "don't send pleroma user agent" do
      assert RequestBuilder.headers(%Request{}, []) == %Request{headers: []}
    end

    test "send pleroma user agent" do
      clear_config([:http, :send_user_agent], true)
      clear_config([:http, :user_agent], :default)

      assert RequestBuilder.headers(%Request{}, []) == %Request{
               headers: [{"user-agent", Pleroma.Application.user_agent()}]
             }
    end

    test "send custom user agent" do
      clear_config([:http, :send_user_agent], true)
      clear_config([:http, :user_agent], "totally-not-pleroma")

      assert RequestBuilder.headers(%Request{}, []) == %Request{
               headers: [{"user-agent", "totally-not-pleroma"}]
             }
    end
  end

  describe "add_param/4" do
    test "add file parameter" do
      %Request{
        body: %Tesla.Multipart{
          boundary: _,
          content_type_params: [],
          parts: [
            %Tesla.Multipart.Part{
              body: %File.Stream{
                line_or_bytes: 2048,
                modes: [:raw, :read_ahead, :read, :binary],
                path: "some-path/filename.png",
                raw: true
              },
              dispositions: [name: "filename.png", filename: "filename.png"],
              headers: []
            }
          ]
        }
      } = RequestBuilder.add_param(%Request{}, :file, "filename.png", "some-path/filename.png")
    end

    test "add key to body" do
      %{
        body: %Tesla.Multipart{
          boundary: _,
          content_type_params: [],
          parts: [
            %Tesla.Multipart.Part{
              body: "\"someval\"",
              dispositions: [name: "somekey"],
              headers: [{"content-type", "application/json"}]
            }
          ]
        }
      } = RequestBuilder.add_param(%{}, :body, "somekey", "someval")
    end

    test "add form parameter" do
      assert RequestBuilder.add_param(%{}, :form, "somename", "someval") == %{
               body: %{"somename" => "someval"}
             }
    end

    test "add for location" do
      assert RequestBuilder.add_param(%{}, :some_location, "somekey", "someval") == %{
               some_location: [{"somekey", "someval"}]
             }
    end
  end
end
