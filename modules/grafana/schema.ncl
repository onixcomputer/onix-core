{
  server = {
    enablePrometheusIntegration = { type = "bool", default = true, description = "Auto-configure Prometheus as datasource" },
    prometheusUrl = { type = "nullable_string", default = null, description = "Prometheus URL (auto-detected when null)" },
    settings = { type = "record", default = {}, description = "Grafana settings (server, security, etc.)" },
    additionalDatasources = { type = "array", default = [], description = "Extra Grafana datasources" },
    dashboards = { type = "array", default = [], description = "Dashboard definitions" },
    notifiers = { type = "array", default = [], description = "Notification channels" },
  },
}
