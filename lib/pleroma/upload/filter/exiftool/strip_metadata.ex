# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.Exiftool.StripMetadata do
  @moduledoc """
  Tries to strip all image metadata but colorspace and orientation overwriting the file in place.
  Also strips or replaces filesystem metadata e.g., timestamps.
  """
  @behaviour Pleroma.Upload.Filter

  alias Pleroma.Config

  @purge_default ["all", "CommonIFD0"]
  @preserve_default ["ColorSpaceTags", "Orientation"]

  @spec filter(Pleroma.Upload.t()) :: {:ok, :noop} | {:ok, :filtered} | {:error, String.t()}

  # Formats not compatible with exiftool at this time
  def filter(%Pleroma.Upload{content_type: "image/webp"}), do: {:ok, :noop}
  def filter(%Pleroma.Upload{content_type: "image/svg+xml"}), do: {:ok, :noop}

  def filter(%Pleroma.Upload{tempfile: file, content_type: "image" <> _}) do
    purge_args =
      Config.get([__MODULE__, :purge], @purge_default)
      |> Enum.map(fn mgroup -> "-" <> mgroup <> "=" end)

    preserve_args =
      Config.get([__MODULE__, :preserve], @preserve_default)
      |> Enum.map(fn mgroup -> "-" <> mgroup end)
      |> then(fn
        # If -TagsFromFile is not followed by tag selectors, it will copy most available tags
        [] -> []
        args -> ["-TagsFromFile", "@" | args]
      end)

    args = ["-ignoreMinorErrors", "-overwrite_original" | purge_args] ++ preserve_args ++ [file]

    try do
      case System.cmd("exiftool", args, parallelism: true) do
        {_response, 0} -> {:ok, :filtered}
        {error, 1} -> {:error, error}
      end
    rescue
      e in ErlangError ->
        {:error, "#{__MODULE__}: #{inspect(e)}"}
    end
  end

  def filter(_), do: {:ok, :noop}
end
