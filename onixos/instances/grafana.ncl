# Clan instance grafana (inventory/services/services.ncl): every machine
# tagged monitoring.
{
  grafana = {
    service = "grafana",
    roles.server = {
      tags = ["monitoring"],
      settings = {
        enable_prometheus_integration = true,
        settings = {
          server = {
            http_addr = "0.0.0.0",
            http_port = 3000,
            domain = "grafana.local",
            root_url = "https://%(domain)s/",
            enable_gzip = true,
          },
          security.admin_user = "admin",
          analytics = {
            reporting_enabled = false,
            check_for_updates = false,
          },
          users = {
            allow_sign_up = false,
            default_theme = "dark",
          },
          feature_toggles.enable = "publicDashboards",
          database = {
            type = "sqlite3",
            path = "/var/lib/grafana/data/grafana.db",
          },
        },
      },
    },
  },
}
