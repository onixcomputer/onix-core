# RustFS Build Cache Specification Delta

## MODIFIED Requirements

### Requirement: Private niks3 service
r[onix.rustfs_build_caches.niks3] The system MUST run pinned niks3 with PostgreSQL metadata, a dedicated signing key, and a Tailnet-only endpoint. niks3 object data MUST use a cache-only RustFS process that does not serve Celld buckets.

#### Scenario: Read a signed store path
r[onix.rustfs_build_caches.niks3.read]
- GIVEN a path was uploaded through authenticated niks3
- WHEN another trusted Tailnet node requests the path from the read proxy
- THEN Nix verifies its signature and copies the path

#### Scenario: Isolate cache object traffic
r[onix.rustfs_build_caches.niks3.isolation]
- GIVEN Celld uses the distributed RustFS cluster
- WHEN niks3 uploads or reads a cache object
- THEN the object operation uses a distinct RustFS process, port, data directory, and credential set
- AND the cache process has no Celld bucket authority

### Requirement: Fleet upload maintenance
r[onix.rustfs_build_caches.uploaders] The three build nodes MUST retain durable niks3 queues, but automatic post-build activation MUST remain disabled until continuous coordination availability is proven.

#### Scenario: Complete a normal Nix build
r[onix.rustfs_build_caches.uploaders.disabled]
- GIVEN no upload maintenance window is active
- WHEN Nix completes a build
- THEN the build succeeds without starting a niks3 uploader
- AND existing durable queue rows remain unchanged

#### Scenario: Admit a manual queue drain
r[onix.rustfs_build_caches.uploaders.maintenance]
- GIVEN an operator selects one node for maintenance
- AND the maintenance marker exists
- AND every configured guard endpoint is healthy
- WHEN the operator starts the uploader socket and service
- THEN at most one upload request runs at a time
- AND the durable queue makes bounded progress

#### Scenario: Reject unsafe drain admission
r[onix.rustfs_build_caches.uploaders.reject]
- GIVEN the maintenance marker is absent or one guard endpoint is unhealthy
- WHEN the uploader service starts
- THEN systemd rejects the start before queue work begins
- AND no durable queue row is deleted

## ADDED Requirements

### Requirement: Storage and coordination monitoring
r[onix.rustfs_build_caches.monitoring] The system MUST expose queue depth and MUST probe RustFS, Celld, and niks3 availability and latency through Prometheus.

#### Scenario: Backlog or service degradation occurs
r[onix.rustfs_build_caches.monitoring.alert]
- GIVEN an uploader queue remains deep or a health endpoint becomes slow or unavailable
- WHEN Prometheus evaluates the configured rules
- THEN a bounded warning or critical alert becomes active
- AND the alert identifies the affected node or endpoint

### Requirement: Authoritative backup and restore
r[onix.rustfs_build_caches.recovery] The system MUST back up Celld object buckets and niks3 PostgreSQL metadata to storage on `britton-desktop`.

#### Scenario: Scheduled backups complete
r[onix.rustfs_build_caches.recovery.backup]
- GIVEN the source services are healthy
- WHEN scheduled backup units run
- THEN Celld bucket objects and a consistent niks3 database dump reach the configured desktop backup root
- AND disposable Kache and niks3 cache objects are excluded

#### Scenario: Restore probes run
r[onix.rustfs_build_caches.recovery.restore]
- GIVEN a completed object snapshot and PostgreSQL dump
- WHEN bounded restore probes run in isolated targets
- THEN restored bytes match their source digest
- AND the restored database exposes the expected niks3 schema

#### Scenario: Backup input is missing
r[onix.rustfs_build_caches.recovery.reject]
- GIVEN no completed snapshot or database dump exists
- WHEN a restore probe starts
- THEN it fails without changing production buckets or the production database
