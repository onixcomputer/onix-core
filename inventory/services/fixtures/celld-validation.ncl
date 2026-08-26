let sc = import "../settings-contracts.ncl" in
let default_public_port = 39200 in
let default_internal_port = 39201 in
let default_lease_ttl_milliseconds = 10000 in
let default_restart_delay_seconds = 10 in
let default_shutdown_drain_milliseconds = 25000 in
let invalid_port = 70000 in
let test_address = "100.64.0.1" in
{
  positive =
    sc.validate_fields
      "celld:server"
      "celld-positive"
      {
        runtimeName = "celld",
        stateDir = "/var/lib/celld-lab",
        bindAddress = test_address,
        storageEndpoint = "http://%{test_address}:39000",
        bucketName = "celld-lab",
        region = "us-east-1",
        accessKeyId = "celld-lab",
        publisherUser = null,
        publicPort = default_public_port,
        internalPort = default_internal_port,
        openFirewall = true,
        firewallInterface = "tailscale0",
        provisionStorage = true,
        rustfsAdminGenerator = "rustfs-rustfs-cluster",
        deployCounter = true,
        leaseTtlMilliseconds = default_lease_ttl_milliseconds,
        restartDelaySeconds = default_restart_delay_seconds,
        shutdownDrainMilliseconds = default_shutdown_drain_milliseconds,
      },
  negative =
    sc.validate_fields
      "celld:server"
      "celld-negative"
      {
        runtimeName = false,
        stateDir = false,
        bindAddress = 0,
        storageEndpoint = [],
        bucketName = {},
        region = false,
        accessKeyId = [],
        publisherUser = 0,
        publicPort = invalid_port,
        internalPort = "peer",
        openFirewall = "yes",
        firewallInterface = [],
        provisionStorage = "yes",
        rustfsAdminGenerator = 0,
        deployCounter = "yes",
        leaseTtlMilliseconds = "lease",
        restartDelaySeconds = "restart",
        shutdownDrainMilliseconds = "drain",
      },
}
