let default_public_port = 8080 in
let default_internal_port = 8081 in
let default_lease_ttl_milliseconds = 10000 in
let default_restart_delay_seconds = 10 in
let default_shutdown_drain_milliseconds = 25000 in
{
  server = {
    runtimeName = { type = "string", default = "celld", description = "Unique systemd unit and Unix identity stem for this instance" },
    stateDir = { type = "string", default = "/var/lib/celld", description = "Private local SQLite and replication working directory" },
    bindAddress = { type = "string", default = "127.0.0.1", description = "Explicit Tailnet address for public and internal listeners" },
    storageEndpoint = { type = "string", default = "http://127.0.0.1:9000", description = "S3-compatible RustFS endpoint used by this Celld node" },
    bucketName = { type = "string", default = "celld-fleet", description = "Dedicated RustFS bucket that owns one Celld fleet" },
    region = { type = "string", default = "us-east-1", description = "S3 region reported by RustFS" },
    accessKeyId = { type = "string", default = "celld-fleet", description = "Stable RustFS user and AWS access-key identifier" },
    publisherUser = { type = "nullable_string", default = null, description = "Optional local user that receives a standard AWS publisher profile" },
    publicPort = { type = "port", default = default_public_port, description = "Tailnet-only public ingress port" },
    internalPort = { type = "port", default = default_internal_port, description = "Tailnet-only peer and operator listener port" },
    stripTrailingSlashProxy = { type = "bool", default = false, description = "Normalize trailing-slash asset paths before Celld 0.3 routing" },
    backendAddress = { type = "string", default = "127.0.0.1", description = "Loopback address for the Celld Worker listener behind the compatibility proxy" },
    backendPort = { type = "port", default = 8082, description = "Private Celld Worker listener behind the compatibility proxy" },
    openFirewall = { type = "bool", default = false, description = "Admit the configured listeners through the NixOS firewall" },
    firewallInterface = { type = "nullable_string", default = "tailscale0", description = "Private interface that admits Celld listeners" },
    provisionStorage = { type = "bool", default = false, description = "Reconcile the bucket, user, policy, and Worker deployment on this node" },
    rustfsAdminGenerator = { type = "string", default = "rustfs-rustfs-cluster", description = "Clan generator that owns the RustFS administrator environment file" },
    deployCounter = { type = "bool", default = true, description = "Deploy the bounded counter Worker from the designated provisioner" },
    leaseTtlMilliseconds = { type = "number", default = default_lease_ttl_milliseconds, description = "Celld node lease lifetime in milliseconds" },
    restartDelaySeconds = { type = "number", default = default_restart_delay_seconds, description = "Systemd restart delay, at least one lease lifetime" },
    shutdownDrainMilliseconds = { type = "number", default = default_shutdown_drain_milliseconds, description = "Graceful ownership handoff deadline in milliseconds" },
  },
}
