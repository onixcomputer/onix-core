let default_node_port = 8776 in
let default_storage_quota_gib = 64 in
{
  default = {
    expectedHost = { type = "string", description = "Exact managed machine admitted as the independent replica" },
    deploymentTarget = { type = "string", description = "Pinned deployment target; never inferred from a public endpoint" },
    expectedNodeFingerprint = { type = "string", description = "Pinned SHA-256 fingerprint of the replica-only node key" },
    alias = { type = "string", description = "Public Radicle node alias" },
    failureDomain = { type = "string", description = "Explicit machine and storage failure-domain label" },
    monitoringRequired = { type = "bool", default = true, description = "Require Prometheus systemd-unit monitoring" },
    nodeListenAddress = { type = "string", description = "Explicit non-wildcard tailnet address" },
    nodeListenPort = { type = "port", default = default_node_port, description = "Native Radicle peer port" },
    nodeFirewallInterface = { type = "string", description = "Single interface allowed to receive native Radicle traffic" },
    externalAddress = { type = "string", description = "Advertised Radicle host and port" },
    seedRepositories = { type = "array_string", default = [], description = "Exact canonical public RID allowlist" },
    privateSeedRepositories = { type = "array_string", default = [], description = "Exact canonical private RID allowlist admitted only over native Radicle" },
    stateDirectory = { type = "string", default = "/var/lib/radicle", description = "Dedicated replica state mount" },
    stateDataset = { type = "string", description = "Dedicated ZFS dataset identity" },
    stateQuotaGiB = { type = "number", default = default_storage_quota_gib, description = "Hard upper storage quota in GiB" },
    minimumSignedRefsFeature = { type = "enum", values = ["parent"], default = "parent", description = "Minimum signed-reference acquisition policy" },
  },
}
