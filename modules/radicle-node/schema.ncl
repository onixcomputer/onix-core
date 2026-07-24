# r[impl onix.radicle_node.configuration]
let default_node_port = 8776 in
let default_http_port = 8080 in
{
  default = {
    expectedHost = { type = "string", default = "aspen1", description = "Machine hostname admitted to run the bootstrap Radicle node" },
    deploymentTarget = { type = "string", default = "root@aspen1.local", description = "Reviewed Clan deployment target; not a public client endpoint" },
    expectedNodeFingerprint = { type = "string", description = "Pinned SSH fingerprint of the recovered persistent Aspen1 node identity" },
    alias = { type = "string", description = "Public Radicle node alias" },
    failureDomain = { type = "string", description = "Explicit physical or administrative failure-domain label" },
    monitoringRequired = { type = "bool", default = true, description = "Require Prometheus and the systemd exporter to observe both Radicle units" },
    nodeListenAddress = { type = "string", description = "Explicit non-wildcard address for native Radicle peer traffic" },
    nodeListenPort = { type = "port", default = default_node_port, description = "Native Radicle peer TCP port" },
    nodeFirewallInterface = { type = "string", description = "Single interface allowed to receive native Radicle peer traffic" },
    externalAddress = { type = "nullable_string", default = null, description = "Optional advertised Radicle host and port; deployment hostname inference is forbidden" },
    seedRepositories = { type = "array_string", default = [], description = "Canonical public Radicle repository IDs admitted by the native seeding-policy reconciler" },
    httpdEnabled = { type = "bool", default = true, description = "Enable the read-only Radicle HTTP gateway" },
    httpListenAddress = { type = "string", default = "127.0.0.1", description = "Loopback address for the read-only Radicle HTTP gateway" },
    httpListenPort = { type = "port", default = default_http_port, description = "Loopback Radicle HTTP gateway port" },
    httpsServerName = { type = "nullable_string", default = null, description = "Optional public HTTPS origin; null keeps the gateway local-only" },
    httpsGitRepositories = { type = "array_string", default = [], description = "Canonical public Radicle repository IDs admitted to exact read-only HTTPS Git routes" },
    minimumSignedRefsFeature = { type = "enum", values = ["root", "parent"], default = "parent", description = "Minimum signed-reference feature required by acquisition probes" },
    pinnedRepositories = { type = "array_string", default = [], description = "Public Radicle repository IDs pinned in explorer metadata; this does not authorize seeding or filter HTTP storage" },
  },
}
