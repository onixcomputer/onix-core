let sc = import "../settings-contracts.ncl" in
let default_restart_delay_seconds = 5 in
{
  positive =
    sc.validate_fields
      "kache-rustfs:client"
      "kache-rustfs-positive"
      {
        cacheDir = "/var/cache/kache-nix/user-brittonr",
        cacheMaxSize = "32GiB",
        serviceUser = "brittonr",
        storageEndpoint = "http://100.110.43.11:39000",
        bucketName = "onix-kache",
        region = "us-east-1",
        prefix = "artifacts",
        accessKeyId = "kache-remote",
        provisionStorage = true,
        rustfsAdminGenerator = "rustfs-rustfs-cluster",
        restartDelaySeconds = default_restart_delay_seconds,
      },
  negative =
    sc.validate_fields
      "kache-rustfs:client"
      "kache-rustfs-negative"
      {
        cacheDir = false,
        cacheMaxSize = [],
        serviceUser = 0,
        storageEndpoint = {},
        bucketName = [],
        region = false,
        prefix = {},
        accessKeyId = [],
        provisionStorage = "yes",
        rustfsAdminGenerator = 0,
        restartDelaySeconds = "restart",
      },
}
