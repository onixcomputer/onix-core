let default_port = 39400 in
{
  server = {
    bindAddress = { type = "string", default = "127.0.0.1", description = "Explicit Tailnet listener address" },
    port = { type = "port", default = default_port, description = "Tailnet read and upload port" },
    storageEndpoint = { type = "string", default = "http://127.0.0.1:39000", description = "Private RustFS S3 endpoint" },
    bucketName = { type = "string", default = "onix-niks3", description = "Dedicated RustFS bucket" },
    region = { type = "string", default = "us-east-1", description = "RustFS S3 region" },
    accessKeyId = { type = "string", default = "niks3-cache", description = "Dedicated RustFS user and access key" },
    provisionStorage = { type = "bool", default = false, description = "Reconcile the bucket, user, and policy on this node" },
    rustfsAdminGenerator = { type = "string", default = "rustfs-rustfs-cluster", description = "Clan generator with RustFS administrator credentials" },
    openFirewall = { type = "bool", default = false, description = "Admit the listener on the private interface" },
    firewallInterface = { type = "nullable_string", default = "tailscale0", description = "Private interface for the listener" },
    gcOlderThan = { type = "string", default = "720h", description = "Minimum closure age for garbage collection" },
    gcFailedUploadsOlderThan = { type = "string", default = "6h", description = "Minimum failed-upload age for cleanup" },
    gcSchedule = { type = "string", default = "daily", description = "Systemd calendar for garbage collection" },
    maxNarSize = { type = "nullable_string", default = "8G", description = "Maximum uncompressed NAR size" },
  },
  uploader = {
    serverUrl = { type = "string", default = "http://127.0.0.1:%{default_port}", description = "Private niks3 upload endpoint" },
    batchSize = { type = "number", default = 50, description = "Store paths per upload batch" },
    idleExitTimeoutSeconds = { type = "number", default = 0, description = "Idle exit timeout; zero keeps the daemon resident" },
    maxConcurrentUploads = { type = "number", default = 8, description = "Bounded concurrent upload count" },
    verifyS3Integrity = { type = "bool", default = true, description = "Verify RustFS objects before skipping uploads" },
  },
}
