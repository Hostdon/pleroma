defmodule Pleroma.Web.Plugs.CSPNoncePlug do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    assign_csp_nonce(conn)
  end

  defp assign_csp_nonce(conn) do
    nonce =
      :crypto.strong_rand_bytes(128)
      |> Base.url_encode64()
      |> binary_part(0, 15)

    conn
    |> assign(:csp_nonce, nonce)
  end
end
