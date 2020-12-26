# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.RateLimiter do
  @moduledoc """

  ## Configuration

  A keyword list of rate limiters where a key is a limiter name and value is the limiter configuration.
  The basic configuration is a tuple where:

  * The first element: `scale` (Integer). The time scale in milliseconds.
  * The second element: `limit` (Integer). How many requests to limit in the time scale provided.

  It is also possible to have different limits for unauthenticated and authenticated users: the keyword value must be a
  list of two tuples where the first one is a config for unauthenticated users and the second one is for authenticated.

  To disable a limiter set its value to `nil`.

  ### Example

      config :pleroma, :rate_limit,
        one: {1000, 10},
        two: [{10_000, 10}, {10_000, 50}],
        foobar: nil

  Here we have three limiters:

  * `one` which is not over 10req/1s
  * `two` which has two limits: 10req/10s for unauthenticated users and 50req/10s for authenticated users
  * `foobar` which is disabled

  ## Usage

  AllowedSyntax:

      plug(Pleroma.Plugs.RateLimiter, name: :limiter_name)
      plug(Pleroma.Plugs.RateLimiter, options)   # :name is a required option

  Allowed options:

      * `name` required, always used to fetch the limit values from the config
      * `bucket_name` overrides name for counting purposes (e.g. to have a separate limit for a set of actions)
      * `params` appends values of specified request params (e.g. ["id"]) to bucket name

  Inside a controller:

      plug(Pleroma.Plugs.RateLimiter, [name: :one] when action == :one)
      plug(Pleroma.Plugs.RateLimiter, [name: :two] when action in [:two, :three])

      plug(
        Pleroma.Plugs.RateLimiter,
        [name: :status_id_action, bucket_name: "status_id_action:fav_unfav", params: ["id"]]
        when action in ~w(fav_status unfav_status)a
      )

  or inside a router pipeline:

      pipeline :api do
        ...
        plug(Pleroma.Plugs.RateLimiter, name: :one)
        ...
      end
  """
  import Pleroma.Web.TranslationHelpers
  import Plug.Conn

  alias Pleroma.Config
  alias Pleroma.Plugs.RateLimiter.LimiterSupervisor
  alias Pleroma.User

  require Logger

  @doc false
  def init(plug_opts) do
    plug_opts
  end

  def call(conn, plug_opts) do
    if disabled?(conn) do
      handle_disabled(conn)
    else
      action_settings = action_settings(plug_opts)
      handle(conn, action_settings)
    end
  end

  defp handle_disabled(conn) do
    Logger.warn(
      "Rate limiter disabled due to forwarded IP not being found. Please ensure your reverse proxy is providing the X-Forwarded-For header or disable the RemoteIP plug/rate limiter."
    )

    conn
  end

  defp handle(conn, nil), do: conn

  defp handle(conn, action_settings) do
    action_settings
    |> incorporate_conn_info(conn)
    |> check_rate()
    |> case do
      {:ok, _count} ->
        conn

      {:error, _count} ->
        render_throttled_error(conn)
    end
  end

  def disabled?(conn) do
    localhost_or_socket =
      case Config.get([Pleroma.Web.Endpoint, :http, :ip]) do
        {127, 0, 0, 1} -> true
        {0, 0, 0, 0, 0, 0, 0, 1} -> true
        {:local, _} -> true
        _ -> false
      end

    remote_ip_not_found =
      if Map.has_key?(conn.assigns, :remote_ip_found),
        do: !conn.assigns.remote_ip_found,
        else: false

    localhost_or_socket and remote_ip_not_found
  end

  @inspect_bucket_not_found {:error, :not_found}

  def inspect_bucket(conn, bucket_name_root, plug_opts) do
    with %{name: _} = action_settings <- action_settings(plug_opts) do
      action_settings = incorporate_conn_info(action_settings, conn)
      bucket_name = make_bucket_name(%{action_settings | name: bucket_name_root})
      key_name = make_key_name(action_settings)
      limit = get_limits(action_settings)

      case Cachex.get(bucket_name, key_name) do
        {:error, :no_cache} ->
          @inspect_bucket_not_found

        {:ok, nil} ->
          {0, limit}

        {:ok, value} ->
          {value, limit - value}
      end
    else
      _ -> @inspect_bucket_not_found
    end
  end

  def action_settings(plug_opts) do
    with limiter_name when is_atom(limiter_name) <- plug_opts[:name],
         limits when not is_nil(limits) <- Config.get([:rate_limit, limiter_name]) do
      bucket_name_root = Keyword.get(plug_opts, :bucket_name, limiter_name)

      %{
        name: bucket_name_root,
        limits: limits,
        opts: plug_opts
      }
    end
  end

  defp check_rate(action_settings) do
    bucket_name = make_bucket_name(action_settings)
    key_name = make_key_name(action_settings)
    limit = get_limits(action_settings)

    case Cachex.get_and_update(bucket_name, key_name, &increment_value(&1, limit)) do
      {:commit, value} ->
        {:ok, value}

      {:ignore, value} ->
        {:error, value}

      {:error, :no_cache} ->
        initialize_buckets!(action_settings)
        check_rate(action_settings)
    end
  end

  defp increment_value(nil, _limit), do: {:commit, 1}

  defp increment_value(val, limit) when val >= limit, do: {:ignore, val}

  defp increment_value(val, _limit), do: {:commit, val + 1}

  defp incorporate_conn_info(action_settings, %{
         assigns: %{user: %User{id: user_id}},
         params: params
       }) do
    Map.merge(action_settings, %{
      mode: :user,
      conn_params: params,
      conn_info: "#{user_id}"
    })
  end

  defp incorporate_conn_info(action_settings, %{params: params} = conn) do
    Map.merge(action_settings, %{
      mode: :anon,
      conn_params: params,
      conn_info: "#{ip(conn)}"
    })
  end

  defp ip(%{remote_ip: remote_ip}) do
    remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end

  defp render_throttled_error(conn) do
    conn
    |> render_error(:too_many_requests, "Throttled")
    |> halt()
  end

  defp make_key_name(action_settings) do
    ""
    |> attach_selected_params(action_settings)
    |> attach_identity(action_settings)
  end

  defp get_scale(_, {scale, _}), do: scale

  defp get_scale(:anon, [{scale, _}, {_, _}]), do: scale

  defp get_scale(:user, [{_, _}, {scale, _}]), do: scale

  defp get_limits(%{limits: {_scale, limit}}), do: limit

  defp get_limits(%{mode: :user, limits: [_, {_, limit}]}), do: limit

  defp get_limits(%{limits: [{_, limit}, _]}), do: limit

  defp make_bucket_name(%{mode: :user, name: bucket_name_root}),
    do: user_bucket_name(bucket_name_root)

  defp make_bucket_name(%{mode: :anon, name: bucket_name_root}),
    do: anon_bucket_name(bucket_name_root)

  defp attach_selected_params(input, %{conn_params: conn_params, opts: plug_opts}) do
    params_string =
      plug_opts
      |> Keyword.get(:params, [])
      |> Enum.sort()
      |> Enum.map(&Map.get(conn_params, &1, ""))
      |> Enum.join(":")

    [input, params_string]
    |> Enum.join(":")
    |> String.replace_leading(":", "")
  end

  defp initialize_buckets!(%{name: _name, limits: nil}), do: :ok

  defp initialize_buckets!(%{name: name, limits: limits}) do
    {:ok, _pid} =
      LimiterSupervisor.add_or_return_limiter(anon_bucket_name(name), get_scale(:anon, limits))

    {:ok, _pid} =
      LimiterSupervisor.add_or_return_limiter(user_bucket_name(name), get_scale(:user, limits))

    :ok
  end

  defp attach_identity(base, %{mode: :user, conn_info: conn_info}),
    do: "user:#{base}:#{conn_info}"

  defp attach_identity(base, %{mode: :anon, conn_info: conn_info}),
    do: "ip:#{base}:#{conn_info}"

  defp user_bucket_name(bucket_name_root), do: "user:#{bucket_name_root}" |> String.to_atom()
  defp anon_bucket_name(bucket_name_root), do: "anon:#{bucket_name_root}" |> String.to_atom()
end
