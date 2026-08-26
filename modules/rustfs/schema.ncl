let default_api_port = 9000 in
let default_console_port = 9001 in
let default_topology_wait_timeout_seconds = 120 in
let default_backup_retention_days = 14 in
{
  server = {
    mode = { type = "enum", values = ["single", "distributed"], default = "single", description = "Storage topology mode" },
    serviceName = { type = "string", default = "rustfs", description = "Distinct systemd service name for this instance" },
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
    cpuWeight = { type = "number", default = 100, description = "Systemd CPU scheduling weight" },
    ioWeight = { type = "number", default = 100, description = "Systemd I/O scheduling weight" },
    nice = { type = "number", default = 0, description = "Process scheduling priority" },
    oomScoreAdjust = { type = "number", default = -1000, description = "Kernel out-of-memory selection adjustment" },
  },
  backup = {
    sourceEndpoint = { type = "string", default = "http://127.0.0.1:39000", description = "RustFS endpoint that serves authoritative source buckets" },
    buckets = { type = "array_string", default = [], description = "Authoritative buckets copied into each snapshot" },
    targetDir = { type = "string", default = "/var/backup/rustfs", description = "Independent filesystem snapshot root" },
    schedule = { type = "string", default = "*-*-* 02:45:00", description = "Object snapshot calendar" },
    retentionDays = { type = "number", default = default_backup_retention_days, description = "Completed snapshot retention" },
    adminGenerator = { type = "string", default = "rustfs-rustfs-cluster", description = "Clan generator with source RustFS administrator credentials" },
    restoreProbeBucket = { type = "string", default = "onix-restore-probe", description = "Temporary bucket used only by bounded restore probes" },
  },
}
