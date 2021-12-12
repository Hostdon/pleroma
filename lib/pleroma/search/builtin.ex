defmodule Pleroma.Search.Builtin do
  @behaviour Pleroma.Search

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Activity
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView
  alias Pleroma.Web.Endpoint

  require Logger

  @impl Pleroma.Search
  def search(_conn, %{q: query} = params, options) do
    version = Keyword.get(options, :version)
    timeout = Keyword.get(Repo.config(), :timeout, 15_000)
    default_values = %{"statuses" => [], "accounts" => [], "hashtags" => []}

    default_values
    |> Enum.map(fn {resource, default_value} ->
      if params[:type] in [nil, resource] do
        {resource, fn -> resource_search(version, resource, query, options) end}
      else
        {resource, fn -> default_value end}
      end
    end)
    |> Task.async_stream(fn {resource, f} -> {resource, with_fallback(f)} end,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce(default_values, fn
      {:ok, {resource, result}}, acc ->
        Map.put(acc, resource, result)

      _error, acc ->
        acc
    end)
  end

  defp resource_search(_, "accounts", query, options) do
    accounts = with_fallback(fn -> User.search(query, options) end)

    AccountView.render("index.json",
      users: accounts,
      for: options[:for_user],
      embed_relationships: options[:embed_relationships]
    )
  end

  defp resource_search(_, "statuses", query, options) do
    statuses = with_fallback(fn -> Activity.search(options[:for_user], query, options) end)

    StatusView.render("index.json",
      activities: statuses,
      for: options[:for_user],
      as: :activity
    )
  end

  defp resource_search(:v2, "hashtags", query, options) do
    tags_path = Endpoint.url() <> "/tag/"

    query
    |> prepare_tags(options)
    |> Enum.map(fn tag ->
      %{name: tag, url: tags_path <> tag}
    end)
  end

  defp resource_search(:v1, "hashtags", query, options) do
    prepare_tags(query, options)
  end

  defp prepare_tags(query, options) do
    tags =
      query
      |> preprocess_uri_query()
      |> String.split(~r/[^#\w]+/u, trim: true)
      |> Enum.uniq_by(&String.downcase/1)

    explicit_tags = Enum.filter(tags, fn tag -> String.starts_with?(tag, "#") end)

    tags =
      if Enum.any?(explicit_tags) do
        explicit_tags
      else
        tags
      end

    tags = Enum.map(tags, fn tag -> String.trim_leading(tag, "#") end)

    tags =
      if Enum.empty?(explicit_tags) && !options[:skip_joined_tag] do
        add_joined_tag(tags)
      else
        tags
      end

    Pleroma.Pagination.paginate(tags, options)
  end

  # If `query` is a URI, returns last component of its path, otherwise returns `query`
  defp preprocess_uri_query(query) do
    if query =~ ~r/https?:\/\// do
      query
      |> String.trim_trailing("/")
      |> URI.parse()
      |> Map.get(:path)
      |> String.split("/")
      |> Enum.at(-1)
    else
      query
    end
  end

  defp add_joined_tag(tags) do
    tags
    |> Kernel.++([joined_tag(tags)])
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp joined_tag(tags) do
    tags
    |> Enum.map(fn tag -> String.capitalize(tag) end)
    |> Enum.join()
  end

  defp with_fallback(f, fallback \\ []) do
    try do
      f.()
    rescue
      error ->
        Logger.error("#{__MODULE__} search error: #{inspect(error)}")
        fallback
    end
  end
end
