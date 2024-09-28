# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Preload do
  alias Phoenix.HTML

  def build_tags(%{assigns: %{csp_nonce: nonce}}, params) do
    preload_data =
      Enum.reduce(Pleroma.Config.get([__MODULE__, :providers], []), %{}, fn parser, acc ->
        terms =
          params
          |> parser.generate_terms()
          |> Enum.map(fn {k, v} -> {k, Base.encode64(Jason.encode!(v))} end)
          |> Enum.into(%{})

        Map.merge(acc, terms)
      end)

    rendered_html =
      preload_data
      |> Jason.encode!()
      |> build_script_tag(nonce)
      |> HTML.safe_to_string()

    rendered_html
  end

  def build_script_tag(content, nonce) do
    HTML.Tag.content_tag(:script, HTML.raw(content),
      id: "initial-results",
      type: "application/json",
      nonce: nonce
    )
  end
end
