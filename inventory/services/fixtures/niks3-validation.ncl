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
        storageServiceName = "rustfs",
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
        metadataBackupEnabled = true,
        metadataBackupEndpoint = "http://100.100.103.95:39000",
        metadataBackupBucket = "onix-niks3-metadata-backup",
        metadataBackupAccessKeyId = "niks3-metadata-backup",
        metadataBackupAdminGenerator = "rustfs-rustfs-cluster",
        metadataBackupDirectory = "/var/backup/niks3",
        metadataBackupSchedule = "*-*-* 02:15:00",
      },
  server_negative =
    sc.validate_fields
      "niks3:server"
      "niks3-server-negative"
      {
        bindAddress = 0,
        port = invalid_port,
        storageEndpoint = {},
        storageServiceName = false,
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
        metadataBackupEnabled = "yes",
        metadataBackupEndpoint = [],
        metadataBackupBucket = false,
        metadataBackupAccessKeyId = [],
        metadataBackupAdminGenerator = {},
        metadataBackupDirectory = false,
        metadataBackupSchedule = [],
      },
  uploader_positive =
    sc.validate_fields
      "niks3:uploader"
      "niks3-uploader-positive"
      {
        serverUrl = "http://100.100.103.95:%{default_port}",
        automaticUploads = false,
        maintenanceMarker = "/run/niks3-maintenance-window",
        maintenanceGuardUrls = ["http://100.100.103.95:39000/health"],
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
        automaticUploads = "yes",
        maintenanceMarker = false,
        maintenanceGuardUrls = "health",
        batchSize = "batch",
        idleExitTimeoutSeconds = false,
        maxConcurrentUploads = "uploads",
        verifyS3Integrity = "yes",
      },
}
