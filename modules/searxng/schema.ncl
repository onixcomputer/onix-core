let default_port : Number = 8888 in
let kagi_timeout_seconds : Number = 10 in
{
  server = {
    bindAddress = { type = "string", default | String = "127.0.0.1", description = "HTTP listener address" },
    port = { type = "port", default | Number = default_port, description = "HTTP listener port" },
    baseUrl = { type = "nullable_string", default = null, description = "External HTTP or HTTPS URL, or null for automatic detection" },
    instanceName = { type = "string", default | String = "SearXNG", description = "Name shown in the search interface" },
    enableJson = { type = "bool", default | Bool = true, description = "Enable JSON search results for API clients" },
    enableKagi = { type = "bool", default | Bool = false, description = "Enable the private, opt-in Kagi session engine (personal subscription, no official API)" },
    kagiDefault = { type = "bool", default | Bool = false, description = "Enable Kagi for ordinary general searches in authorized browsers" },
    kagiHealthCheck = { type = "bool", default | Bool = false, description = "Run a daily Kagi session canary and expose failures through systemd monitoring" },
    kagiTimeoutSeconds = { type = "number", default | Number = kagi_timeout_seconds, description = "Maximum duration of a Kagi engine request in seconds" },
    limiter = { type = "bool", default | Bool = true, description = "Enable rate limits and a local Redis service" },
    openFirewall = { type = "bool", default | Bool = false, description = "Open the HTTP port on the selected firewall interface" },
    firewallInterface = { type = "string", default | String = "tailscale0", description = "Firewall interface used when openFirewall is true" },
  },
}
