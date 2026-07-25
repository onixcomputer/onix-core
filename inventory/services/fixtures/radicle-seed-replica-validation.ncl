# r[verify onix.radicle_replica.configuration]
# r[verify onix.radicle_replica.validation]
let sc = import "../settings-contracts.ncl" in
let default_node_port = 8776 in
let default_storage_quota_gib = 64 in
{
  positive =
    sc.validate_fields
      "radicle-seed-replica:default"
      "radicle-seed-replica-positive"
      {
        expectedHost = "britton-desktop",
        deploymentTarget = "root@100.110.43.11",
        expectedNodeFingerprint = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        alias = "britton-desktop-radicle",
        failureDomain = "britton-desktop-workstation",
        monitoringRequired = true,
        nodeListenAddress = "100.110.43.11",
        nodeListenPort = default_node_port,
        nodeFirewallInterface = "tailscale0",
        externalAddress = "100.110.43.11:8776",
        seedRepositories = [
          "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo",
          "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f",
        ],
        stateDirectory = "/var/lib/radicle",
        stateDataset = "datapool/radicle-seed",
        stateQuotaGiB = default_storage_quota_gib,
        minimumSignedRefsFeature = "parent",
      },
  negative =
    sc.validate_fields
      "radicle-seed-replica:default"
      "radicle-seed-replica-negative"
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
        stateDirectory = false,
        stateDataset = 1,
        stateQuotaGiB = "unbounded",
        minimumSignedRefsFeature = "leaf",
      },
}
