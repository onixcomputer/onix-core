# RustFS Cluster Specification Delta

## MODIFIED Requirements

### Requirement: One service composes the cluster
r[onix.rustfs_cluster.composition] The inventory MUST model the distributed coordination deployment as one Clan service instance spanning all selected machines. A cache-only standalone RustFS instance MAY coexist when it has a distinct unit, port, data directory, credentials, and authority.

#### Scenario: Inventory expansion
r[onix.rustfs_cluster.composition.inventory]
- GIVEN the RustFS cluster instance
- WHEN Clan expands the server role
- THEN `aspen1`, `aspen3`, and `britton-desktop` receive the same cluster service
- AND no standalone instance serves the distributed cluster namespace
- AND any co-located cache instance cannot serve coordination buckets

## ADDED Requirements

### Requirement: Multiple instances remain distinct
r[onix.rustfs_cluster.instances] A host with more than one RustFS instance MUST generate distinct systemd units and MUST reject conflicting instance identities.

#### Scenario: Compose a cluster and cache instance
r[onix.rustfs_cluster.instances.compose]
- GIVEN one distributed instance and one standalone cache instance share a host
- WHEN NixOS generates the machine configuration
- THEN each instance receives its configured service name and volume
- AND each service has independent credentials and resource controls

#### Scenario: Reject an invalid service identity
r[onix.rustfs_cluster.instances.reject]
- GIVEN an empty or unsafe systemd service name
- WHEN RustFS settings are validated
- THEN evaluation fails before deployment
