{
  server = {
    enableAutoDiscovery = { type = "bool", default = true, description = "Auto-discover and scrape exporters" },
    discoveryMethod = { type = "enum", values = ["none", "tailscale", "dns", "static"], default = "none", description = "Service discovery method" },
    port = { type = "port", default = 9090, description = "Prometheus server port" },
    retentionTime = { type = "string", default = "30d", description = "Metric retention period" },
    globalConfig = { type = "record", default = {}, description = "Prometheus global configuration" },
    additionalScrapeConfigs = { type = "array", default = [], description = "Additional scrape configurations" },
    rules = { type = "array", default = [], description = "Alerting rule YAML documents" },
    # dnsDiscovery and staticTargets use NixOS submodules — typed as record, validated at build time
    staticTargets = { type = "record", default = {}, description = "Static targets per job" },
    dnsDiscovery = { type = "record", default = {}, description = "DNS discovery configuration per job" },
  },
  exporter = {
    exporterType = { type = "enum", values = ["node", "systemd", "nginx", "postgres", "redis", "blackbox", "snmp", "json", "domain"], description = "Exporter type" },
    port = { type = "port", default = 9100, description = "Exporter metrics port" },
    enabledCollectors = { type = "array_string", default = [], description = "Enabled collector names" },
  },
}
