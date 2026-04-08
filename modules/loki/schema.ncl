{
  server = {
    enableAlloy = { type = "bool", default = true, description = "Enable Grafana Alloy log collector alongside Loki" },
    configuration = { type = "record", default = {}, description = "Loki server configuration" },
    lokiUrl = { type = "string", default = "http://localhost:3100", description = "Loki push URL used by the co-located Alloy instance" },
    additionalFileScrapes = { type = "array", default = [], description = "File paths to scrape (list of {name, path, labels})" },
    alloyExtraConfig = { type = "string", default = "", description = "Additional raw Alloy River config appended to the generated config" },
  },
  alloy = {
    lokiUrl = { type = "string", default = "http://localhost:3100", description = "Loki server URL for log push endpoint" },
    additionalFileScrapes = { type = "array", default = [], description = "File paths to scrape (list of {name, path, labels})" },
    alloyExtraConfig = { type = "string", default = "", description = "Additional raw Alloy River config appended to the generated config" },
  },
}
