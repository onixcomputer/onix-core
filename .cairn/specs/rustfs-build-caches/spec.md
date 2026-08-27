# RustFS Build Cache Specification

## Purpose

Define private Kache and niks3 build caches backed by separate RustFS authorities.

## Requirements

### Requirement: Separate storage authority
r[onix.rustfs_build_caches.storage] The system MUST give Kache and niks3 separate RustFS buckets, principals, policies, and generated credentials.

#### Scenario: Provision narrow buckets
r[onix.rustfs_build_caches.storage.provision]
- GIVEN RustFS administrator credentials on a designated node
- WHEN cache storage provisioning runs
- THEN each cache receives only its configured bucket authority
- AND neither runtime receives RustFS administrator credentials

#### Scenario: Reject unsafe storage settings
r[onix.rustfs_build_caches.storage.reject]
- GIVEN an empty bucket, access key, endpoint, or administrator generator
- WHEN service settings are validated
- THEN evaluation fails before deployment

### Requirement: Kache remote artifact cache
r[onix.rustfs_build_caches.kache] Aspen1, Aspen3, and `britton-desktop` MUST run managed Kache Cargo wrappers and credentialed system daemons that synchronize compatible Rust artifacts through the dedicated RustFS bucket.

#### Scenario: Upload Kache artifacts
r[onix.rustfs_build_caches.kache.upload]
- GIVEN a successful interactive Rust build on a configured node
- WHEN the managed Kache wrapper completes compilation
- THEN its node-local daemon MUST synchronize compatible artifacts through the configured RustFS endpoint
- AND another configured node MUST be able to reuse the accepted artifact

#### Scenario: Use bounded node-local storage
r[onix.rustfs_build_caches.kache.storage]
- GIVEN the three nodes have different storage layouts
- WHEN Kache configuration is generated
- THEN every daemon MUST receive an absolute bounded local cache path
- AND Aspen3 MUST place Kache data on its USB4 volume
- AND exactly one node MUST provision shared bucket authority

#### Scenario: Preserve Nix sandbox authority
r[onix.rustfs_build_caches.kache.sandbox]
- GIVEN a Nix derivation uses the Nix-owned Kache wrapper
- WHEN it compiles Rust in a sandbox
- THEN the wrapper MUST remain local-only
- AND the sandbox MUST receive no RustFS credential file

#### Scenario: Remote cache is unavailable
r[onix.rustfs_build_caches.kache.unavailable]
- GIVEN RustFS or a Kache daemon is unavailable
- WHEN Cargo compiles a valid Rust input
- THEN compilation MUST remain able to use the real compiler
- AND cache failure MUST NOT convert a valid compiler result into corrupted output

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

### Requirement: Verification coverage
r[onix.rustfs_build_caches.verification] The system MUST include typed positive and negative fixtures, pure settings tests, generated configuration checks, complete machine builds, and bounded runtime evidence.

#### Scenario: Verify generated authority
r[onix.rustfs_build_caches.verification.generated]
- GIVEN the generated NixOS configurations
- WHEN focused checks inspect them
- THEN cache ports are absent from global firewall ports
- AND runtime users, credentials, signing trust, upload hooks, and bucket settings match the reviewed contract

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
