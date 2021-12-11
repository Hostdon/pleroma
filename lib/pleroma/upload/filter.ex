# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter do
  @moduledoc """
  Upload Filter behaviour

  This behaviour allows to run filtering actions just before a file is uploaded. This allows to:

  * morph in place the temporary file
  * change any field of a `Pleroma.Upload` struct
  * cancel/stop the upload
  """

  require Logger

  @callback filter(upload :: struct()) ::
              {:ok, :filtered}
              | {:ok, :noop}
              | {:ok, :filtered, upload :: struct()}
              | {:error, any()}

  @spec filter([module()], upload :: struct()) :: {:ok, upload :: struct()} | {:error, any()}

  def filter([], upload) do
    {:ok, upload}
  end

  def filter([filter | rest], upload) do
    case filter.filter(upload) do
      {:ok, :filtered} ->
        filter(rest, upload)

      {:ok, :filtered, upload} ->
        filter(rest, upload)

      {:ok, :noop} ->
        filter(rest, upload)

      error ->
        Logger.error("#{__MODULE__}: Filter #{filter} failed: #{inspect(error)}")
        error
    end
  end
end
