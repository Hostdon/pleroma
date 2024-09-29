defmodule Pleroma.Web.MastodonAPI.TagView do
  use Pleroma.Web, :view
  alias Pleroma.User

  def render("index.json", %{tags: tags, for_user: user}) do
    render_many(tags, __MODULE__, "show.json", %{for_user: user})
  end

  def render("show.json", %{tag: tag, for_user: user}) do
    following =
      with %User{} <- user do
        User.following_hashtag?(user, tag)
      else
        _ -> false
      end

    %{
      name: tag.name,
      url: url(~p[/tags/#{tag.name}]),
      history: [],
      following: following
    }
  end
end
