let default_api_port = 9000 in
let default_console_port = 9001 in
let default_topology_wait_timeout_seconds = 120 in
{
  server = {
    mode = { type = "enum", values = ["single", "distributed"], default = "single", description = "Storage topology mode" },
    dataDir = { type = "string", default = "/var/lib/rustfs", description = "Persistent RustFS data directory local to this node" },
    bindAddress = { type = "string", default = "0.0.0.0", description = "Address for the S3 API, peer traffic, and console listeners" },
    apiPort = { type = "port", default = default_api_port, description = "S3 API and distributed peer port" },
    consolePort = { type = "port", default = default_console_port, description = "Web console port" },
    enableConsole = { type = "bool", default = true, description = "Enable the RustFS web console" },
    openFirewall = { type = "bool", default = false, description = "Open the configured RustFS ports" },
    firewallInterface = { type = "nullable_string", default = "tailscale0", description = "Firewall interface for RustFS ports, or null for all interfaces" },
    clusterEndpoints = { type = "array_string", default = [], description = "Canonical ordered HTTP endpoint URLs supplied to every distributed node" },
    topologyWaitMode = { type = "enum", values = ["bounded", "fail-fast"], default = "bounded", description = "Peer topology convergence policy for bare-metal nodes" },
    topologyWaitTimeoutSeconds = { type = "number", default = default_topology_wait_timeout_seconds, description = "Maximum distributed topology convergence wait in seconds" },
  },
}
