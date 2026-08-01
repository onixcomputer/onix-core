# Radicle Replica Specification

## Purpose

Defines the `radicle-replica` capability.

## Requirements

### Requirement: Replica configuration is typed and bounded

r[onix.radicle_replica.configuration] `onix-core` MUST validate and deterministically lower each selected replica host from an exact reviewed host matrix without enabling HTTP or repository governance authority.

#### Scenario: Reviewed replica configurations are admitted

r[onix.radicle_replica.configuration.accepted]
- GIVEN the reviewed package and exact host facts for `britton-desktop` or `aspen3`
- WHEN the replica configuration is evaluated
- THEN it MUST lower one hardened default-block Radicle node and authoritative policy reconciler
- AND it MUST use the reviewed target, failure domain, dataset, tailnet listener, exact repository sets, monitoring, quota, fingerprint, and signed-reference policy
- AND it MUST enable no HTTP, HTTPS, Cloudflare, ACME, delegate, CI, deployment, release, canonical-ref, cache-write, backup, or artifact-administration input

#### Scenario: Unsafe replica configuration is rejected

r[onix.radicle_replica.configuration.rejected]
- GIVEN an unknown host, mismatched reviewed fact, Aspen1 identity reuse, weak signed refs, unsafe listener, invalid RID, missing monitoring, or unbounded storage
- WHEN validation runs
- THEN evaluation MUST fail with a stable diagnostic before deployment

### Requirement: Replica deployment preserves least authority

r[onix.radicle_replica.deployment] `onix-core` MUST deploy each replica with a distinct machine-scoped node identity, dedicated bounded state, exact policy, interface-scoped firewall, and no repository governance authority.

#### Scenario: Aspen3 starts with its pinned identity

r[onix.radicle_replica.deployment.identity]
- GIVEN the Clan-generated `aspen3` private and public key pair and reviewed public fingerprint
- WHEN the `aspen3` replica starts or restarts
- THEN it MUST verify the public fingerprint before node execution
- AND a mismatch MUST prevent service activation without deleting state

### Requirement: Seed service has no privileged forge authority

r[onix.radicle_replica.authority] The replica service MUST receive only its machine-scoped Radicle node key and public repository storage permissions.

#### Scenario: Service authority is inspected

r[onix.radicle_replica.authority.inspected]
- GIVEN the deployed service process and systemd unit
- WHEN credential, environment, mount, home, capability, and secret-path boundaries are inspected
- THEN delegate, CI, deployment, release, canonical-ref, cache-write, artifact, backup, Cloudflare, and user-profile authority MUST be absent from the service
- AND host-root compromise resistance MUST remain an explicit non-claim

### Requirement: Independent native availability is observed

r[onix.radicle_replica.availability] The replica MUST provide the exact reviewed pilot Git object to an independent native client while Aspen1's native node is unavailable.

#### Scenario: Desktop replica survives Aspen1 node outage

r[onix.radicle_replica.availability.outage]
- GIVEN both seeds store the exact pilot RID and Aspen1's native node is stopped
- WHEN a fresh client with egress restricted to the desktop replica clones using signed-reference feature `parent`
- THEN it MUST resolve commit `29dac88ecded94457572db3fdfaaaab95fa91525`
- AND source archive BLAKE3 MUST match the reviewed publication source
- AND Aspen1 MUST be restored before the drill ends

#### Scenario: Undeclared native repository is rejected

r[onix.radicle_replica.availability.rejection]
- GIVEN the client can reach only the desktop replica
- WHEN it requests an undeclared inherited or public RID
- THEN acquisition MUST fail without public-seed or GitHub fallback

### Requirement: Replica evidence is deterministic and redaction-safe

r[onix.radicle_replica.evidence] `onix-core` MUST record redaction-safe evidence for each accepted replica deployment and bind durable receipts with BLAKE3 when issued.

#### Scenario: Aspen3 deployment evidence is recorded

r[onix.radicle_replica.evidence.accepted]
- GIVEN the `aspen3` configuration and live positive and negative checks pass
- WHEN deployment evidence is recorded
- THEN the evidence MUST identify policy, package, machine, failure domain, identity, storage, listeners, services, repository counts, and explicit non-claims
- AND it MUST exclude keys, credentials, raw environments, private content, user-home data, and unbounded logs

### Requirement: Replica validation has positive and negative coverage

r[onix.radicle_replica.validation] The replica module and all production assignments MUST have positive and negative deterministic checks before deployment or receipt acceptance.

#### Scenario: Focused validation covers the replica fleet

r[onix.radicle_replica.validation.focused]
- GIVEN module, inventory, identity, storage, listener, policy, monitoring, authority, and evidence fixtures
- WHEN focused Nix and Cairn checks run
- THEN both reviewed host configurations MUST pass
- AND unknown hosts, mismatched host facts, and duplicate seed identities MUST fail with expected diagnostics

### Requirement: Interactive desktop nodes remain isolated

r[onix.radicle_replica.desktop_isolation] `aspen3` MUST keep Radicle Desktop state, control sockets, and listeners separate from the managed seed service.

#### Scenario: Desktop uses a separate user profile

r[onix.radicle_replica.desktop_isolation.profile]
- GIVEN `aspen3` runs the managed seed and Radicle Desktop
- WHEN the user starts Radicle Desktop or its user node
- THEN the user processes MUST use `/home/brittonr/.radicle` and its control socket
- AND the user processes MUST NOT use `/var/lib/radicle` or the managed seed control socket

#### Scenario: User listener overrides are rejected

r[onix.radicle_replica.desktop_isolation.listener]
- GIVEN the managed seed listens on its reviewed tailnet address at port `8776`
- WHEN the user starts `radicle-node` through the desktop profile
- THEN the wrapper MUST use an operating-system-selected loopback port
- AND explicit `--listen` arguments MUST fail before node execution

#### Scenario: Raw binaries cannot claim the managed port

r[onix.radicle_replica.desktop_isolation.bind_guard]
- GIVEN a process runs in the desktop user's system-managed slice
- WHEN the process tries to bind TCP port `8776`
- THEN the kernel bind filter MUST reject the request
- AND the filter MUST apply before the user session starts

### Requirement: Seed identities remain distinct

r[onix.radicle_replica.identity_distinct] Each persistent Radicle seed MUST use a different machine-scoped node identity.

#### Scenario: Production seed fingerprints are compared

r[onix.radicle_replica.identity_distinct.production]
- GIVEN the Aspen1, `britton-desktop`, and `aspen3` production settings
- WHEN focused replica validation compares their pinned fingerprints
- THEN all three fingerprints MUST be unique
- AND a duplicate fingerprint MUST fail validation before deployment
