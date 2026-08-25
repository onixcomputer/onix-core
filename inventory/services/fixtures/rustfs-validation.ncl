let sc = import "../settings-contracts.ncl" in
let default_api_port = 9000 in
let default_console_port = 9001 in
let invalid_port = 70000 in
{
  positive =
    sc.validate_fields
      "rustfs:server"
      "rustfs-positive"
      {
        dataDir = "/var/lib/rustfs",
        bindAddress = "0.0.0.0",
        apiPort = default_api_port,
        consolePort = default_console_port,
        enableConsole = true,
        openFirewall = true,
        firewallInterface = "tailscale0",
      },
  negative =
    sc.validate_fields
      "rustfs:server"
      "rustfs-negative"
      {
        dataDir = false,
        bindAddress = 0,
        apiPort = invalid_port,
        consolePort = "console",
        enableConsole = "yes",
        openFirewall = "yes",
        firewallInterface = {},
      },
}
