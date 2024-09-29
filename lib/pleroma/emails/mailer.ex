# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Emails.Mailer do
  @moduledoc """
  Defines the Pleroma mailer.

  The module contains functions to delivery email using Swoosh.Mailer.
  """

  alias Pleroma.Workers.MailerWorker
  alias Swoosh.DeliveryError

  @otp_app :pleroma
  @mailer_config [otp: :pleroma]

  @spec enabled?() :: boolean()
  def enabled?, do: Pleroma.Config.get([__MODULE__, :enabled])

  @doc "add email to queue"
  def deliver_async(email, config \\ []) do
    encoded_email =
      email
      |> :erlang.term_to_binary()
      |> Base.encode64()

    MailerWorker.enqueue("email", %{"encoded_email" => encoded_email, "config" => config})
  end

  @doc "callback to perform send email from queue"
  def perform(:deliver_async, email, config), do: deliver(email, config)

  @spec deliver(Swoosh.Email.t(), Keyword.t()) :: {:ok, term} | {:error, term}
  def deliver(email, config \\ [])

  def deliver(email, config) do
    case enabled?() do
      true -> Swoosh.Mailer.deliver(email, parse_config(config))
      false -> {:error, :deliveries_disabled}
    end
  end

  @spec deliver!(Swoosh.Email.t(), Keyword.t()) :: term | no_return
  def deliver!(email, config \\ [])

  def deliver!(email, config) do
    case deliver(email, config) do
      {:ok, result} -> result
      {:error, reason} -> raise DeliveryError, reason: reason
    end
  end

  @on_load :validate_dependency

  @doc false
  def validate_dependency do
    parse_config([], defaults: false)
    |> Keyword.get(:adapter)
    |> Swoosh.Mailer.validate_dependency()
  end

  defp ensure_charlist(input) do
    case input do
      i when is_binary(i) -> String.to_charlist(input)
      i when is_list(i) -> i
    end
  end

  defp default_config(adapter, conf, opts)

  defp default_config(_, _, defaults: false) do
    []
  end

  defp default_config(Swoosh.Adapters.SMTP, conf, _) do
    # gen_smtp and Erlang's tls defaults are very barebones, if nothing is set.
    # Add sane defaults for our usecase to make config less painful for admins
    relay = ensure_charlist(Keyword.get(conf, :relay))
    ssl_disabled = Keyword.get(conf, :ssl) === false
    os_cacerts = :public_key.cacerts_get()

    common_tls_opts = [
      cacerts: os_cacerts,
      versions: [:"tlsv1.2", :"tlsv1.3"],
      verify: :verify_peer,
      # some versions have supposedly issues verifying wildcard certs without this
      server_name_indication: relay,
      # the default of 10 is too restrictive
      depth: 32
    ]

    [
      auth: :always,
      no_mx_lookups: false,
      # Direct SSL/TLS
      # (if ssl was explicitly disabled, we must not pass TLS options to the socket)
      ssl: true,
      sockopts: if(ssl_disabled, do: [], else: common_tls_opts),
      # STARTTLS upgrade (can't be set to :always when already using direct TLS)
      tls: :if_available,
      tls_options: common_tls_opts
    ]
  end

  defp default_config(_, _, _), do: []

  defp parse_config(config, opts \\ []) do
    conf = Swoosh.Mailer.parse_config(@otp_app, __MODULE__, @mailer_config, config)
    adapter = Keyword.get(conf, :adapter)

    default_config(adapter, conf, opts)
    |> Keyword.merge(conf)
  end
end
