# r[verify onix.radicle_node.configuration]
let sc = import "../settings-contracts.ncl" in
let default_node_port = 8776 in
let default_http_port = 8080 in
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
        httpdEnabled = true,
        httpListenAddress = "127.0.0.1",
        httpListenPort = default_http_port,
        httpsServerName = null,
        httpsGitRepositories = [],
        minimumSignedRefsFeature = "parent",
        pinnedRepositories = ["rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5"],
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
        httpdEnabled = "yes",
        httpListenAddress = 1,
        httpListenPort = "not-a-port",
        httpsServerName = 1,
        httpsGitRepositories = [1],
        minimumSignedRefsFeature = "leaf",
        pinnedRepositories = [1],
      },
}
