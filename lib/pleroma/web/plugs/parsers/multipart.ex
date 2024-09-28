defmodule Pleroma.Web.Plugs.Parsers.Multipart do
  @multipart Plug.Parsers.MULTIPART

  alias Pleroma.Config

  def init(opts) do
    opts
  end

  def parse(conn, "multipart", subtype, headers, opts) do
    length = Config.get([:instance, :upload_limit])

    opts = @multipart.init([length: length] ++ opts)

    @multipart.parse(conn, "multipart", subtype, headers, opts)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
