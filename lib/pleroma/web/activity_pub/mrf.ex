# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF do
  require Logger

  @behaviour Pleroma.Web.ActivityPub.MRF.PipelineFiltering

  @mrf_config_descriptions [
    %{
      group: :pleroma,
      key: :mrf,
      tab: :mrf,
      label: "MRF",
      type: :group,
      description: "General MRF settings",
      children: [
        %{
          key: :policies,
          type: [:module, {:list, :module}],
          description:
            "A list of MRF policies enabled. Module names are shortened (removed leading `Pleroma.Web.ActivityPub.MRF.` part), but on adding custom module you need to use full name.",
          suggestions: {:list_behaviour_implementations, Pleroma.Web.ActivityPub.MRF.Policy}
        },
        %{
          key: :transparency,
          label: "MRF transparency",
          type: :boolean,
          description:
            "Make the content of your Message Rewrite Facility settings public (via nodeinfo)"
        },
        %{
          key: :transparency_exclusions,
          label: "MRF transparency exclusions",
          type: {:list, :tuple},
          key_placeholder: "instance",
          value_placeholder: "reason",
          description:
            "Exclude specific instance names from MRF transparency. The use of the exclusions feature will be disclosed in nodeinfo as a boolean value. You can also provide a reason for excluding these instance names. The instances and reasons won't be publicly disclosed.",
          suggestions: [
            "exclusion.com"
          ]
        },
        %{
          key: :transparency_obfuscate_domains,
          label: "MRF domain obfuscation",
          type: {:list, :string},
          description:
            "Obfuscate domains in MRF transparency. This is useful if the domain you're blocking contains words you don't want displayed, but still want to disclose the MRF settings.",
          suggestions: [
            "badword.com"
          ]
        }
      ]
    }
  ]

  @default_description %{
    label: "",
    description: ""
  }

  @required_description_keys [:key, :related_policy]

  def filter_one(policy, %{"type" => type} = message)
      when type in ["Undo", "Block", "Delete"] and
             policy != Pleroma.Web.ActivityPub.MRF.SimplePolicy do
    {:ok, message}
  end

  def filter_one(policy, message) do
    should_plug_history? =
      if function_exported?(policy, :history_awareness, 0) do
        policy.history_awareness()
      else
        :manual
      end
      |> Kernel.==(:auto)

    if not should_plug_history? do
      policy.filter(message)
    else
      main_result = policy.filter(message)

      with {_, {:ok, main_message}} <- {:main, main_result},
           {_,
            %{
              "formerRepresentations" => %{
                "orderedItems" => [_ | _]
              }
            }} = {_, object} <- {:object, message["object"]},
           {_, {:ok, new_history}} <-
             {:history,
              Pleroma.Object.Updater.for_each_history_item(
                object["formerRepresentations"],
                object,
                fn item ->
                  with {:ok, filtered} <- policy.filter(Map.put(message, "object", item)) do
                    {:ok, filtered["object"]}
                  else
                    e -> e
                  end
                end
              )} do
        {:ok, put_in(main_message, ["object", "formerRepresentations"], new_history)}
      else
        {:main, _} -> main_result
        {:object, _} -> main_result
        {:history, e} -> e
      end
    end
  end

  def filter(policies, %{} = message) do
    policies
    |> Enum.reduce({:ok, message}, fn
      policy, {:ok, message} -> filter_one(policy, message)
      _, error -> error
    end)
  end

  def filter(%{} = object), do: get_policies() |> filter(object)

  @impl true
  def pipeline_filter(%{} = message, meta) do
    object = meta[:object_data]
    ap_id = message["object"]

    if object && ap_id do
      with {:ok, message} <- filter(Map.put(message, "object", object)) do
        meta = Keyword.put(meta, :object_data, message["object"])
        {:ok, Map.put(message, "object", ap_id), meta}
      else
        {err, message} -> {err, message, meta}
      end
    else
      {err, message} = filter(message)

      {err, message, meta}
    end
  end

  def get_policies do
    Pleroma.Config.get([:mrf, :policies], [])
    |> get_policies()
    |> Enum.concat([
      Pleroma.Web.ActivityPub.MRF.HashtagPolicy,
      Pleroma.Web.ActivityPub.MRF.InlineQuotePolicy,
      Pleroma.Web.ActivityPub.MRF.NormalizeMarkup
    ])
    |> Enum.uniq()
  end

  defp get_policies(policy) when is_atom(policy), do: [policy]
  defp get_policies(policies) when is_list(policies), do: policies
  defp get_policies(_), do: []

  # Matches the following:
  # - https://baddomain.net
  # - https://extra.baddomain.net/
  # Does NOT match the following:
  # - https://maybebaddomain.net/
  def subdomain_regex("*." <> domain), do: subdomain_regex(domain)

  def subdomain_regex(domain) do
    ~r/^(.+\.)?#{Regex.escape(domain)}$/i
  end

  @spec subdomains_regex([String.t()]) :: [Regex.t()]
  def subdomains_regex(domains) when is_list(domains) do
    Enum.map(domains, &subdomain_regex/1)
  end

  @spec subdomain_match?([Regex.t()], String.t()) :: boolean()
  def subdomain_match?(domains, host) do
    Enum.any?(domains, fn domain -> Regex.match?(domain, host) end)
  end

  @spec instance_list_from_tuples([{String.t(), String.t()}]) :: [String.t()]
  def instance_list_from_tuples(list) do
    Enum.map(list, fn {instance, _} -> instance end)
  end

  def describe(policies) do
    {:ok, policy_configs} =
      policies
      |> Enum.reduce({:ok, %{}}, fn
        policy, {:ok, data} ->
          {:ok, policy_data} = policy.describe()
          {:ok, Map.merge(data, policy_data)}

        _, error ->
          error
      end)

    mrf_policies =
      get_policies()
      |> Enum.map(fn policy -> to_string(policy) |> String.split(".") |> List.last() end)

    exclusions = Pleroma.Config.get([:mrf, :transparency_exclusions])

    base =
      %{
        mrf_policies: mrf_policies,
        exclusions: length(exclusions) > 0
      }
      |> Map.merge(policy_configs)

    {:ok, base}
  end

  def describe, do: get_policies() |> describe()

  def config_descriptions do
    Pleroma.Web.ActivityPub.MRF.Policy
    |> Pleroma.Docs.Generator.list_behaviour_implementations()
    |> config_descriptions()
  end

  def config_descriptions(policies) do
    Enum.reduce(policies, @mrf_config_descriptions, fn policy, acc ->
      if function_exported?(policy, :config_description, 0) do
        description =
          @default_description
          |> Map.merge(policy.config_description)
          |> Map.put(:group, :pleroma)
          |> Map.put(:tab, :mrf)
          |> Map.put(:type, :group)

        if Enum.all?(@required_description_keys, &Map.has_key?(description, &1)) do
          [description | acc]
        else
          Logger.warn(
            "#{policy} config description doesn't have one or all required keys #{inspect(@required_description_keys)}"
          )

          acc
        end
      else
        Logger.debug(
          "#{policy} is excluded from config descriptions, because does not implement `config_description/0` method."
        )

        acc
      end
    end)
  end
end
