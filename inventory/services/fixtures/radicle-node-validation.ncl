# r[verify onix.radicle_node.configuration]
let sc = import "../settings-contracts.ncl" in
let default_node_port = 8776 in
let default_http_port = 8080 in
let default_https_origin_port = 8081 in
let default_backup_quota_gib = 256 in
let default_backup_retention_daily = 7 in
let default_backup_retention_weekly = 4 in
{
  positive =
    sc.validate_fields
      "radicle-node:default"
      "radicle-node-positive"
      {
        expectedHost = "aspen1",
        deploymentTarget = "root@aspen1.local",
        expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
        alias = "aspen1-radicle",
        failureDomain = "aspen-primary-site",
        monitoringRequired = true,
        nodeListenAddress = "100.100.103.95",
        nodeListenPort = default_node_port,
        nodeFirewallInterface = "tailscale0",
        externalAddress = "100.100.103.95:8776",
        seedRepositories = [
          "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo",
          "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f",
          "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a",
          "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF",
        ],
        privateSeedRepositories = [
          "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg",
          "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk",
        ],
        httpdEnabled = true,
        httpListenAddress = "127.0.0.1",
        httpListenPort = default_http_port,
        httpsEnabled = false,
        httpsServerName = "git.onix.computer",
        httpsTransport = "cloudflare-tunnel",
        httpsOriginListenAddress = "127.0.0.1",
        httpsOriginListenPort = default_https_origin_port,
        httpsGitRepositories = [],
        backupEnabled = true,
        backupTargetHost = "britton-desktop",
        backupTargetAddress = "100.110.43.11",
        backupTargetFailureDomain = "britton-desktop-workstation",
        backupRepositoryPath = "/var/lib/radicle-backup",
        backupDataset = "datapool/radicle-backup",
        backupDatasetQuotaGiB = default_backup_quota_gib,
        backupRetentionDaily = default_backup_retention_daily,
        backupRetentionWeekly = default_backup_retention_weekly,
        backupManifestAlgorithm = "blake3",
        minimumSignedRefsFeature = "parent",
        pinnedRepositories = ["rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo"],
      },
  negative =
    sc.validate_fields
      "radicle-node:default"
      "radicle-node-negative"
      {
        expectedHost = 1,
        deploymentTarget = false,
        expectedNodeFingerprint = false,
        alias = [],
        failureDomain = 1,
        monitoringRequired = "yes",
        nodeListenAddress = 1,
        nodeListenPort = "not-a-port",
        nodeFirewallInterface = false,
        externalAddress = 1,
        seedRepositories = [1],
        privateSeedRepositories = [1],
        httpdEnabled = "yes",
        httpListenAddress = 1,
        httpListenPort = "not-a-port",
        httpsEnabled = "yes",
        httpsServerName = 1,
        httpsTransport = "plaintext",
        httpsOriginListenAddress = 1,
        httpsOriginListenPort = "not-a-port",
        httpsGitRepositories = [1],
        backupEnabled = "yes",
        backupTargetHost = 1,
        backupTargetAddress = 1,
        backupTargetFailureDomain = 1,
        backupRepositoryPath = 1,
        backupDataset = 1,
        backupDatasetQuotaGiB = "unbounded",
        backupRetentionDaily = "forever",
        backupRetentionWeekly = "forever",
        backupManifestAlgorithm = "sha256",
        minimumSignedRefsFeature = "leaf",
        pinnedRepositories = [1],
      },
}
