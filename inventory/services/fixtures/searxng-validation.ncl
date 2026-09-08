let sc = import "../settings-contracts.ncl" in
let default_port : Number = 8888 in
let default_kagi_timeout : Number = 10 in
{
  positive =
    sc.validate_fields
      "searxng:server"
      "searxng-positive"
      {
        bindAddress = "127.0.0.1",
        port = default_port,
        baseUrl = "https://search.example.net/",
        instanceName = "Private search",
        enableJson = true,
        enableDeveloperEngines = true,
        enableTidal = true,
        enableKagi = true,
        kagiDefault = true,
        kagiHealthCheck = true,
        kagiTimeoutSeconds = default_kagi_timeout,
        limiter = true,
        openFirewall = false,
        firewallInterface = "tailscale0",
      },
  negative =
    sc.validate_fields
      "searxng:server"
      "searxng-negative"
      {
        bindAddress = false,
        port = "invalid-port",
        baseUrl = true,
        instanceName = false,
        enableJson = "yes",
        enableDeveloperEngines = "yes",
        enableTidal = "yes",
        enableKagi = "yes",
        kagiDefault = "yes",
        kagiHealthCheck = "yes",
        kagiTimeoutSeconds = "slow",
        limiter = "yes",
        openFirewall = "yes",
        firewallInterface = false,
      },
}
