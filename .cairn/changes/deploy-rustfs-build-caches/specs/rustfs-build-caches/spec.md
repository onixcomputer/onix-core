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
r[onix.rustfs_build_caches.kache] The desktop Kache daemon MUST use its local content-addressed store and MUST synchronize Rust artifacts through its dedicated RustFS bucket.

#### Scenario: Upload Kache artifacts
r[onix.rustfs_build_caches.kache.upload]
- GIVEN a successful interactive Rust build
- WHEN the Kache daemon or operator sync runs
- THEN remote manifests and packs appear only under the configured bucket and prefix

#### Scenario: Preserve Nix sandbox authority
r[onix.rustfs_build_caches.kache.sandbox]
- GIVEN a Nix derivation uses the Nix-owned Kache wrapper
- WHEN it compiles Rust in a sandbox
- THEN the wrapper remains local-only
- AND the sandbox receives no RustFS credential file

### Requirement: Private niks3 service
r[onix.rustfs_build_caches.niks3] The system MUST run pinned niks3 with PostgreSQL metadata, a RustFS data bucket, a dedicated signing key, and a Tailnet-only read and upload endpoint.

#### Scenario: Read a signed store path
r[onix.rustfs_build_caches.niks3.read]
- GIVEN a path was uploaded through authenticated niks3
- WHEN another trusted Tailnet node requests the path from the read proxy
- THEN Nix verifies its signature and copies the path

#### Scenario: Reject anonymous writes
r[onix.rustfs_build_caches.niks3.reject_write]
- GIVEN a client has no API token
- WHEN it requests an upload
- THEN niks3 rejects the request
- AND RustFS state is unchanged

### Requirement: Fleet auto-upload
r[onix.rustfs_build_caches.uploaders] The three RustFS nodes MUST run crash-safe niks3 auto-upload daemons with only the shared API token.

#### Scenario: Queue completed builds
r[onix.rustfs_build_caches.uploaders.queue]
- GIVEN Nix completes a build on a configured node
- WHEN the post-build hook emits its store paths
- THEN the local uploader queues and sends them to niks3

#### Scenario: Server is unavailable
r[onix.rustfs_build_caches.uploaders.unavailable]
- GIVEN niks3 is temporarily unavailable
- WHEN a Nix build completes
- THEN the build result remains valid
- AND the uploader retains or retries queued work without blocking normal substitution

### Requirement: Verification coverage
r[onix.rustfs_build_caches.verification] The system MUST include typed positive and negative fixtures, pure settings tests, generated configuration checks, complete machine builds, and bounded runtime evidence.

#### Scenario: Verify generated authority
r[onix.rustfs_build_caches.verification.generated]
- GIVEN the generated NixOS configurations
- WHEN focused checks inspect them
- THEN cache ports are absent from global firewall ports
- AND runtime users, credentials, signing trust, upload hooks, and bucket settings match the reviewed contract
