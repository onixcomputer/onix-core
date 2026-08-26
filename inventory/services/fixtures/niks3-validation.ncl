let sc = import "../settings-contracts.ncl" in
let default_port = 39400 in
let invalid_port = 70000 in
{
  server_positive =
    sc.validate_fields
      "niks3:server"
      "niks3-server-positive"
      {
        bindAddress = "100.100.103.95",
        port = default_port,
        storageEndpoint = "http://100.100.103.95:39000",
        bucketName = "onix-niks3",
        region = "us-east-1",
        accessKeyId = "niks3-cache",
        provisionStorage = true,
        rustfsAdminGenerator = "rustfs-rustfs-cluster",
        openFirewall = true,
        firewallInterface = "tailscale0",
        gcOlderThan = "720h",
        gcFailedUploadsOlderThan = "6h",
        gcSchedule = "daily",
        maxNarSize = "8G",
      },
  server_negative =
    sc.validate_fields
      "niks3:server"
      "niks3-server-negative"
      {
        bindAddress = 0,
        port = invalid_port,
        storageEndpoint = {},
        bucketName = [],
        region = false,
        accessKeyId = [],
        provisionStorage = "yes",
        rustfsAdminGenerator = 0,
        openFirewall = "yes",
        firewallInterface = [],
        gcOlderThan = {},
        gcFailedUploadsOlderThan = [],
        gcSchedule = false,
        maxNarSize = 0,
      },
  uploader_positive =
    sc.validate_fields
      "niks3:uploader"
      "niks3-uploader-positive"
      {
        serverUrl = "http://100.100.103.95:%{default_port}",
        batchSize = 50,
        idleExitTimeoutSeconds = 0,
        maxConcurrentUploads = 8,
        verifyS3Integrity = true,
      },
  uploader_negative =
    sc.validate_fields
      "niks3:uploader"
      "niks3-uploader-negative"
      {
        serverUrl = [],
        batchSize = "batch",
        idleExitTimeoutSeconds = false,
        maxConcurrentUploads = "uploads",
        verifyS3Integrity = "yes",
      },
}
