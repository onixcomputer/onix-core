# Radicle Node Hosting Specification

## Purpose

Defines the `radicle-node-hosting` capability.

## Requirements

### Requirement: Reviewed Radicle package baseline

r[onix.radicle_node.package] `onix-core` MUST package a reviewed Radicle release at version `1.9.1` or later and MUST reject a deployment whose signed-reference feature policy is weaker than `parent`.

#### Scenario: Reviewed package is admitted

r[onix.radicle_node.package.admitted]
- GIVEN the configured Radicle package meets the named minimum version and signed-reference feature policy
- WHEN the package and service configuration are evaluated
- THEN the node and HTTP components MUST be available from one recorded package identity
- AND the admitted version and feature policy MUST appear in the bootstrap evidence

#### Scenario: Unsafe package is rejected

r[onix.radicle_node.package.rejected]
- GIVEN the configured package is older than the named minimum or enables a weaker signed-reference feature
- WHEN deployment configuration is evaluated
- THEN evaluation MUST fail before creating a deployable service

### Requirement: Typed bootstrap-node configuration

r[onix.radicle_node.configuration] `onix-core` MUST validate the bootstrap machine, failure domain, pinned node-identity fingerprint, package, state, seed, listener, HTTPS, monitoring, retention, backup, restore, and repository-admission facts through typed Nickel configuration before lowering them into Nix services.

#### Scenario: Complete bootstrap configuration lowers deterministically

r[onix.radicle_node.configuration.valid]
- GIVEN `aspen1` is the explicit bootstrap host with deployment target `root@aspen1.local`, persistent state, bounded storage and retention, safe listeners, an HTTPS origin, monitoring, off-host backup policy, and an allowlist containing only admitted public repositories
- WHEN the Nickel configuration is validated and exported
- THEN it MUST produce deterministic inputs for the production node, HTTP, proxy, firewall, backup, and monitoring modules

#### Scenario: Unsafe bootstrap configuration fails closed

r[onix.radicle_node.configuration.invalid]
- GIVEN configuration selects a host other than `aspen1`, changes its recovered node-identity fingerprint, omits its failure-domain fact, uses transient storage, exposes an undeclared wildcard listener, admits a private repository, requests forbidden authority, declares an unsafe endpoint, uses a same-host-only backup, or leaves storage or retention unbounded
- WHEN validation runs
- THEN it MUST reject the configuration before producing deployable service inputs

### Requirement: Least-authority persistent node

r[onix.radicle_node.hosting] `onix-core` MUST run the bootstrap Radicle node on `aspen1` as a dedicated unprivileged service with persistent state and MUST NOT provide access to repository delegate, offline recovery, CI, deployment, release-signing, canonical-ref, cache-administration, artifact-administration, or unrelated co-hosted service authority.

#### Scenario: Node survives restart without authority expansion

r[onix.radicle_node.hosting.restart]
- GIVEN the node deployed to `root@aspen1.local` has an admitted node identity, repository set, and persistent state directory
- WHEN the service or selected machine restarts
- THEN the same node and admitted repository identities MUST return healthy
- AND no forbidden credential or governance capability may be present in the unit, environment, or state directory
- AND the unit MUST remain unable to read Aspen1's Buildbot, Nix-signing, Cloudflare, Vaultwarden, Matrix, or other unrelated service credentials

#### Scenario: Privileged material is injected

r[onix.radicle_node.hosting.privilege-rejected]
- GIVEN a service configuration supplies delegate, CI, deployment, release, canonical-ref, cache, or artifact-administration credentials
- WHEN module assertions evaluate the service
- THEN deployment MUST fail before the privileged material reaches the node

### Requirement: Bounded peer and HTTPS exposure

r[onix.radicle_node.exposure] `onix-core` MUST expose native Radicle synchronization and read-only seed-backed HTTPS Git only through explicitly admitted listener and proxy paths, and MUST keep undeclared repositories and operations inaccessible.

#### Scenario: Exact public object is acquired

r[onix.radicle_node.exposure.acquire]
- GIVEN an admitted public probe or pilot repository and one exact Git object exist in local Radicle storage
- WHEN independent clients acquire the repository through the declared native peer endpoint and HTTPS Git endpoint
- THEN both paths MUST resolve the same exact Git object without fetching that repository from GitHub

#### Scenario: Undeclared access is attempted

r[onix.radicle_node.exposure.denied]
- GIVEN a client requests repository enumeration, an undeclared or private repository, a write operation, or an undeclared listener
- WHEN the request reaches the node or HTTPS boundary
- THEN access MUST fail without exposing repository content or enabling repository mutation

### Requirement: Complete backup and clean restore

r[onix.radicle_node.recovery] `onix-core` MUST back up the complete declared Radicle state required for node identity, repository objects, signed refs, issues, patches, identities, and declared custom COB refs to a target outside Aspen1's failure domain, and MUST bind the bounded backup to a BLAKE3 manifest.

#### Scenario: Clean restore preserves declared identities

r[onix.radicle_node.recovery.restored]
- GIVEN a verified backup and a clean restore root or replacement service
- WHEN the restore procedure runs
- THEN the node ID, repository IDs, exact Git objects, signed refs, issues, patches, identities, and declared custom COB refs MUST match the pre-loss evidence
- AND the restored service MUST pass the same bounded health and acquisition probes

#### Scenario: Backup cannot prove recovery

r[onix.radicle_node.recovery.rejected]
- GIVEN a backup is incomplete, tampered, permission-unsafe, unbounded, or changes a declared identity after restore
- WHEN restore admission verifies the backup and observations
- THEN it MUST reject recovery and MUST NOT present the replacement as the accepted bootstrap node

### Requirement: Verifiable bootstrap prerequisite

r[onix.radicle_node.bootstrap] `onix-core` MUST emit a redaction-safe deterministic receipt that downstream OnixOS, Bounded Exec, and Lattice lifecycle checks can use as the prerequisite for repository publication and source cutover.

#### Scenario: Downstream pilot admits the bootstrap node

r[onix.radicle_node.bootstrap.accepted]
- GIVEN package, configuration, deployment, exposure, restart, monitoring, backup, and restore checks have passed
- WHEN the bootstrap receipt is produced
- THEN it MUST bind the policy, package, machine, failure domain, node ID, admitted repositories, endpoints, exact probe object, backup/restore result, and explicit non-claims
- AND it MUST exclude private keys, credentials, private content, raw environments, and unbounded logs

#### Scenario: One node is presented as high availability

r[onix.radicle_node.bootstrap.non-claim]
- GIVEN only the bootstrap node has accepted evidence
- WHEN a consumer evaluates independent-seed, single-seed-outage, private-confidentiality, CI, review, canonical-ref, or release-readiness claims
- THEN the receipt MUST NOT satisfy those claims
- AND the consumer MUST require their separately owned evidence before advancing the wider pilot

### Requirement: Production definitions receive positive and negative validation

r[onix.radicle_node.validation] `onix-core` MUST test the production package, Nickel contract, Nix service, proxy, firewall, persistence, monitoring, backup, and restore definitions with both admitted and rejected inputs.

#### Scenario: Focused validation detects a deployment regression

r[onix.radicle_node.validation.focused]
- GIVEN production definitions and paired positive and negative fixtures
- WHEN focused Nickel, Nix evaluation, module, service, restart, acquisition, backup, restore, and Cairn checks run
- THEN admitted configurations and exact-object observations MUST pass
- AND unsafe versions, policy, authority, exposure, storage, endpoint, backup, restore, and redaction inputs MUST fail with bounded diagnostics
