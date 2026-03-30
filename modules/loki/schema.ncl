{
  server = {
    enablePromtail = { type = "bool", default = true, description = "Enable Promtail log collector" },
    configuration = { type = "record", default = {}, description = "Loki server configuration" },
    promtailConfig = { type = "record", default = {}, description = "Promtail configuration" },
    lokiUrl = { type = "string", default = "http://localhost:3100", description = "Loki push URL" },
    additionalScrapeConfigs = { type = "array", default = [], description = "Extra Promtail scrape configs" },
  },
  promtail = {
    lokiUrl = { type = "string", default = "http://localhost:3100", description = "Loki server URL" },
    additionalScrapeConfigs = { type = "array", default = [], description = "Extra Promtail scrape configs" },
  },
}
