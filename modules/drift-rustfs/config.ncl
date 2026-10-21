# Private Drift account on the existing RustFS cluster.
{
  user | String = "brittonr",
  account | String = "brittonr",
  bucket | String = "onix-drift",
  prefix | String = "drift/v1",
  endpoint | String = "http://100.110.43.11:39000",
  region | String = "us-east-1",
  accessKeyId | String = "drift-brittonr",
  generator | String = "drift-rustfs-brittonr",
  adminGenerator | String = "rustfs-rustfs-cluster",
  secretByteCount | Number = 32,
  secretMode | String = "0400",
  serviceUmask | String = "0077",
  provisionTimeoutSeconds | Number = 60,
  ytDlp = {
    version | String = "2026.08.19",
    revision | String = "3a08beaf031ab68f966401ead017ac81fe8486cf",
    # Nix fetchTree requires a SHA-256 NAR hash.
    narHash | String = "sha256-BM5ZeGTmHq+1xH6G/zsuCtjLgYgfRA11ya0zIHK5p4g=",
  },
}
