# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config do
  defmodule Error do
    defexception [:message]
  end

  def get(key), do: get(key, nil)

  def get([key], default), do: get(key, default)

  def get([_ | _] = path, default) do
    case fetch(path) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def get(key, default) do
    Application.get_env(:pleroma, key, default)
  end

  def get!(key) do
    value = get(key, nil)

    if value == nil do
      raise(Error, message: "Missing configuration value: #{inspect(key)}")
    else
      value
    end
  end

  def fetch(key) when is_atom(key), do: fetch([key])

  def fetch([root_key | keys]) do
    Enum.reduce_while(keys, Application.fetch_env(:pleroma, root_key), fn
      key, {:ok, config} when is_map(config) or is_list(config) ->
        case Access.fetch(config, key) do
          :error ->
            {:halt, :error}

          value ->
            {:cont, value}
        end

      _key, _config ->
        {:halt, :error}
    end)
  end

  def put([key], value), do: put(key, value)

  def put([parent_key | keys], value) do
    parent =
      Application.get_env(:pleroma, parent_key, [])
      |> put_in(keys, value)

    Application.put_env(:pleroma, parent_key, parent)
  end

  def put(key, value) do
    Application.put_env(:pleroma, key, value)
  end

  def delete([key]), do: delete(key)

  def delete([parent_key | keys] = path) do
    with {:ok, _} <- fetch(path) do
      {_, parent} =
        parent_key
        |> get()
        |> get_and_update_in(keys, fn _ -> :pop end)

      Application.put_env(:pleroma, parent_key, parent)
    end
  end

  def delete(key) do
    Application.delete_env(:pleroma, key)
  end

  def restrict_unauthenticated_access?(resource, kind) do
    setting = get([:restrict_unauthenticated, resource, kind])

    if setting in [nil, :if_instance_is_private] do
      !get!([:instance, :public])
    else
      setting
    end
  end

  def oauth_consumer_strategies, do: get([:auth, :oauth_consumer_strategies], [])

  def oauth_consumer_enabled?, do: oauth_consumer_strategies() != []

  def enforce_oauth_admin_scope_usage?, do: !!get([:auth, :enforce_oauth_admin_scope_usage])

  def oauth_admin_scopes(scopes) when is_list(scopes) do
    Enum.flat_map(
      scopes,
      fn scope ->
        ["admin:#{scope}"] ++
          if enforce_oauth_admin_scope_usage?(), do: [], else: [scope]
      end
    )
  end
end
