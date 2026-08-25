let default_api_port = 9000 in
let default_console_port = 9001 in
{
  server = {
    dataDir = { type = "string", default = "/var/lib/rustfs", description = "Persistent RustFS data directory" },
    bindAddress = { type = "string", default = "0.0.0.0", description = "Address for the S3 API and console listeners" },
    apiPort = { type = "port", default = default_api_port, description = "S3 API port" },
    consolePort = { type = "port", default = default_console_port, description = "Web console port" },
    enableConsole = { type = "bool", default = true, description = "Enable the RustFS web console" },
    openFirewall = { type = "bool", default = false, description = "Open the configured RustFS ports" },
    firewallInterface = { type = "nullable_string", default = "tailscale0", description = "Firewall interface for RustFS ports, or null for all interfaces" },
  },
}
