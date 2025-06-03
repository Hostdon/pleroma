defmodule Pleroma.Web.AkkomaAPI.MetricsControllerTest do
  use Pleroma.Web.ConnCase, async: false

  describe "GET /api/v1/akkoma/metrics" do
    test "should return metrics when the user has admin:metrics" do
      %{conn: conn} = oauth_access(["admin:metrics"])

      Pleroma.PrometheusExporter.gather()

      resp =
        conn
        |> get("/api/v1/akkoma/metrics")
        |> text_response(200)

      assert resp =~ "# HELP"
    end

    test "should not allow users that do not have the admin:metrics scope" do
      %{conn: conn} = oauth_access(["read:metrics"])

      conn
      |> get("/api/v1/akkoma/metrics")
      |> json_response(403)
    end

    test "should be disabled by export_prometheus_metrics" do
      clear_config([:instance, :export_prometheus_metrics], false)
      %{conn: conn} = oauth_access(["admin:metrics"])

      conn
      |> get("/api/v1/akkoma/metrics")
      |> response(404)
    end
  end
end
