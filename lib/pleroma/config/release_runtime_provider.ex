defmodule Pleroma.Config.ReleaseRuntimeProvider do
  @moduledoc """
  Imports `runtime.exs` and `{env}.exported_from_db.secret.exs` for elixir releases.
  """
  @behaviour Config.Provider

  @impl true
  def init(opts), do: opts

  @impl true
  def load(config, _opts) do
    with_defaults = Config.Reader.merge(config, Pleroma.Config.Holder.release_defaults())

    config_path = System.get_env("PLEROMA_CONFIG_PATH") || "/etc/pleroma/config.exs"

    with_runtime_config =
      if File.exists?(config_path) do
        runtime_config = Config.Reader.read!(config_path)

        with_defaults
        |> Config.Reader.merge(pleroma: [config_path: config_path])
        |> Config.Reader.merge(runtime_config)
      else
        warning = [
          IO.ANSI.red(),
          IO.ANSI.bright(),
          "!!! #{config_path} not found! Please ensure it exists and that PLEROMA_CONFIG_PATH is unset or points to an existing file",
          IO.ANSI.reset()
        ]

        IO.puts(warning)
        with_defaults
      end

    exported_config_path =
      config_path
      |> Path.dirname()
      |> Path.join("prod.exported_from_db.secret.exs")

    with_exported =
      if File.exists?(exported_config_path) do
        exported_config = Config.Reader.read!(with_runtime_config)
        Config.Reader.merge(with_runtime_config, exported_config)
      else
        with_runtime_config
      end

    with_exported
  end
end
