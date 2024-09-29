defmodule Pleroma.Web.AkkomaAPI.FrontendSwitcherController do
  use Pleroma.Web, :controller
  alias Pleroma.Config

  @doc "GET /akkoma/frontend"
  def switch(conn, _params) do
    pickable = Config.get([:frontends, :pickable], [])

    conn
    |> put_view(Pleroma.Web.AkkomaAPI.FrontendSwitcherView)
    |> render("switch.html", choices: pickable)
  end

  @doc "POST /akkoma/frontend"
  def do_switch(conn, params) do
    conn
    |> put_resp_cookie("preferred_frontend", params["frontend"])
    |> html("<meta http-equiv=\"refresh\" content=\"0; url=/\">")
  end
end
