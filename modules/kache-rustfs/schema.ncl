{
  client = {
    cacheDir = { type = "string", default = "/var/cache/kache-nix/user-brittonr", description = "Local Kache store owned by the service user" },
    cacheMaxSize = { type = "string", default = "32GiB", description = "Maximum local Kache store size" },
    serviceUser = { type = "string", default = "brittonr", description = "Existing user that owns interactive Kache" },
    storageEndpoint = { type = "string", default = "http://127.0.0.1:39000", description = "Private RustFS S3 endpoint" },
    bucketName = { type = "string", default = "onix-kache", description = "Dedicated RustFS bucket" },
    region = { type = "string", default = "us-east-1", description = "RustFS S3 region" },
    prefix = { type = "string", default = "artifacts", description = "Key prefix inside the Kache bucket" },
    accessKeyId = { type = "string", default = "kache-remote", description = "Dedicated RustFS user and access key" },
    provisionStorage = { type = "bool", default = false, description = "Reconcile the bucket, user, and policy on this node" },
    rustfsAdminGenerator = { type = "string", default = "rustfs-rustfs-cluster", description = "Clan generator with RustFS administrator credentials" },
    restartDelaySeconds = { type = "number", default = 5, description = "Delay before daemon restart" },
  },
}
