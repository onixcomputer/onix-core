let sc = import "../settings-contracts.ncl" in
let default_api_port = 9000 in
let default_console_port = 9001 in
let default_topology_wait_timeout_seconds = 120 in
let default_resource_weight = 100 in
let protected_oom_score_adjust = -1000 in
let backup_retention_days = 14 in
let invalid_port = 70000 in
let test_local_address = "100.64.0.1" in
let test_peer_address_a = "100.64.0.2" in
let test_peer_address_b = "100.64.0.3" in
{
  positive =
    sc.validate_fields
      "rustfs:server"
      "rustfs-positive"
      {
        mode = "distributed",
        serviceName = "rustfs",
        dataDir = "/var/lib/rustfs-cluster",
        bindAddress = test_local_address,
        apiPort = default_api_port,
        consolePort = default_console_port,
        enableConsole = true,
        openFirewall = true,
        firewallInterface = "tailscale0",
        clusterEndpoints = [
          "http://%{test_local_address}:%{default_api_port}/var/lib/rustfs-cluster",
          "http://%{test_peer_address_a}:%{default_api_port}/srv/rustfs-cluster",
          "http://%{test_peer_address_b}:%{default_api_port}/data/rustfs-cluster",
        ],
        topologyWaitMode = "bounded",
        topologyWaitTimeoutSeconds = default_topology_wait_timeout_seconds,
        cpuWeight = default_resource_weight,
        ioWeight = default_resource_weight,
        nice = 0,
        oomScoreAdjust = protected_oom_score_adjust,
      },
  negative =
    sc.validate_fields
      "rustfs:server"
      "rustfs-negative"
      {
        mode = "replicated",
        serviceName = false,
        dataDir = false,
        bindAddress = 0,
        apiPort = invalid_port,
        consolePort = "console",
        enableConsole = "yes",
        openFirewall = "yes",
        firewallInterface = {},
        clusterEndpoints = "cluster",
        topologyWaitMode = "forever",
        topologyWaitTimeoutSeconds = "timeout",
        cpuWeight = "cpu",
        ioWeight = false,
        nice = "nice",
        oomScoreAdjust = [],
      },
  backup_positive =
    sc.validate_fields
      "rustfs:backup"
      "rustfs-backup-positive"
      {
        sourceEndpoint = "http://100.110.43.11:39000",
        buckets = ["onix-celld-lab"],
        targetDir = "/datapool/rustfs-authority-backup",
        schedule = "*-*-* 02:45:00",
        retentionDays = backup_retention_days,
        adminGenerator = "rustfs-rustfs-cluster",
        restoreProbeBucket = "onix-restore-probe",
      },
  backup_negative =
    sc.validate_fields
      "rustfs:backup"
      "rustfs-backup-negative"
      {
        sourceEndpoint = false,
        buckets = "buckets",
        targetDir = [],
        schedule = 0,
        retentionDays = "days",
        adminGenerator = {},
        restoreProbeBucket = false,
      },
}
