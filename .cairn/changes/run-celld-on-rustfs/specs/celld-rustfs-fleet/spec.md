# Celld RustFS Fleet Specification

## Purpose

Provide one private experimental Celld fleet whose Durable Object state uses the existing RustFS cluster without granting access to unrelated buckets.

## ADDED Requirements

### Requirement: Celld release is immutable

r[onix.celld_rustfs.package] The deployment MUST use an immutable Celld release artifact with a verified digest.

#### Scenario: Package execution

r[onix.celld_rustfs.package.version]
- GIVEN the pinned Celld package
- WHEN the packaged executable reports its version
- THEN it reports `celld 0.3.0`
- AND Nix verifies the published release digest before installation

### Requirement: Fleet storage is isolated

r[onix.celld_rustfs.storage] Celld MUST use one dedicated RustFS bucket and one credential whose policy is scoped to that bucket.

#### Scenario: Idempotent provisioning

r[onix.celld_rustfs.storage.provision]
- GIVEN the designated storage provisioner and Clan-generated Celld credential
- WHEN provisioning runs one or more times
- THEN the fleet bucket exists
- AND the Celld user has the bucket-scoped policy
- AND the Celld service does not receive RustFS administrator credentials

#### Scenario: Conditional write fencing

r[onix.celld_rustfs.storage.fencing]
- GIVEN the dedicated Celld bucket and credential
- WHEN Celld runs its storage diagnosis
- THEN conditional create succeeds
- AND duplicate create is rejected
- AND conditional update succeeds
- AND stale update is rejected

### Requirement: One fleet spans three nodes

r[onix.celld_rustfs.composition] The inventory MUST compose one Celld service instance across `aspen1`, `aspen3`, and `britton-desktop`.

#### Scenario: Failure-domain alignment

r[onix.celld_rustfs.composition.nodes]
- GIVEN the three RustFS cluster hosts
- WHEN Celld settings are lowered for each host
- THEN each host runs one Celld node
- AND each node uses the RustFS endpoint on the same host
- AND all nodes use the same bucket and credential

### Requirement: Listeners stay private

r[onix.celld_rustfs.security] Celld Worker and internal listeners MUST bind explicit Tailnet addresses and MUST be admitted only on `tailscale0`.

#### Scenario: Generated network policy

r[onix.celld_rustfs.security.tailnet]
- GIVEN one public port and one internal port
- WHEN NixOS lowers the Celld service and firewall
- THEN neither listener uses a wildcard address
- AND both ports are allowed only on `tailscale0`
- AND the advertised peer address equals the internal Tailnet listener

#### Scenario: Internal authority boundary

r[onix.celld_rustfs.security.credentials]
- GIVEN a running Celld node
- WHEN systemd starts its process
- THEN the process receives only the dedicated bucket credential
- AND no plaintext credential enters the Nix store

### Requirement: Invalid fleet settings fail evaluation

r[onix.celld_rustfs.validation] Pure configuration validation MUST reject unsafe or divergent Celld settings.

#### Scenario: Wildcard listener

r[onix.celld_rustfs.validation.wildcard]
- GIVEN a wildcard public or internal bind address
- WHEN settings validation runs
- THEN evaluation fails with a listener-address error

#### Scenario: Shared listener port

r[onix.celld_rustfs.validation.port]
- GIVEN equal public and internal ports
- WHEN settings validation runs
- THEN evaluation fails with a distinct-port error

#### Scenario: Unsafe bucket name

r[onix.celld_rustfs.validation.bucket]
- GIVEN an empty or malformed bucket name
- WHEN settings validation runs
- THEN evaluation fails with a bucket-name error

#### Scenario: Missing provisioner

r[onix.celld_rustfs.validation.provisioner]
- GIVEN a three-node fleet without exactly one storage provisioner
- WHEN generated topology validation runs
- THEN evaluation fails with a provisioner-count error

### Requirement: Deployment proves durable state

r[onix.celld_rustfs.runtime] Runtime acceptance MUST exercise a deployed Durable Object through every Celld node.

#### Scenario: Cross-node counter

r[onix.celld_rustfs.runtime.counter]
- GIVEN the deployed counter Worker and one named Durable Object
- WHEN clients send sequential requests through all three nodes
- THEN every response advances one shared durable counter
- AND no node returns an independent counter lineage

#### Scenario: Restart persistence

r[onix.celld_rustfs.runtime.restart]
- GIVEN an observed counter value
- WHEN all Celld nodes restart without deleting their RustFS bucket
- THEN the next accepted request returns a greater value

### Requirement: Failure claims require observation

r[onix.celld_rustfs.failure] The fleet MUST NOT claim node-loss tolerance until a live one-node outage test passes.

#### Scenario: One Celld node stops

r[onix.celld_rustfs.failure.one_node]
- GIVEN a healthy three-node Celld fleet with an observed counter value
- WHEN one Celld node stops
- THEN a surviving node advances the same counter
- AND the stopped node rejoins the fleet
- AND a request through the recovered node observes the advanced lineage
