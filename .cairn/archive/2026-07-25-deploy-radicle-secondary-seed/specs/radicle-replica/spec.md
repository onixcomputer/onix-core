## ADDED Requirements

### Requirement: Secondary seed configuration is typed and bounded

r[onix.radicle_replica.configuration] `onix-core` MUST validate and deterministically lower the selected replica host, deployment target, failure domain, dedicated node identity, bounded storage, native listener, exact public repository allowlist, monitoring, and minimum signed-reference policy without enabling HTTP or repository governance authority.

#### Scenario: Reviewed replica configuration is admitted

r[onix.radicle_replica.configuration.accepted]
- GIVEN the reviewed package, desktop host, distinct failure domain, dedicated node fingerprint, quota, tailnet listener, exact pilot RID, monitoring, and signed-reference feature `parent`
- WHEN the replica configuration is evaluated
- THEN it MUST lower one hardened default-block Radicle node and authoritative policy reconciler
- AND it MUST enable no HTTP, HTTPS, Cloudflare, ACME, delegate, CI, deployment, release, canonical-ref, cache-write, or artifact-administration input

#### Scenario: Unsafe replica configuration is rejected

r[onix.radicle_replica.configuration.rejected]
- GIVEN a wrong host or target, Aspen1 identity reuse, weak signed refs, wildcard listener, non-tailnet firewall, invalid or duplicate RID, missing monitoring, unbounded storage, public ingress, or forbidden credential
- WHEN validation runs
- THEN evaluation MUST fail with a stable diagnostic before deployment

### Requirement: Replica deployment preserves least authority

r[onix.radicle_replica.deployment] `onix-core` MUST deploy the replica with a distinct machine-scoped node identity, dedicated bounded state, exact pilot policy, interface-scoped firewall, restart persistence, and no repository governance authority.

#### Scenario: Replica starts with its pinned identity

r[onix.radicle_replica.deployment.identity]
- GIVEN the Clan-generated private/public key pair and reviewed public fingerprint
- WHEN the replica starts or restarts
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

r[onix.radicle_replica.evidence] `onix-core` MUST emit a BLAKE3-bound deployment receipt covering policy, package, machine, failure domain, identity, storage, repository, object, listeners, authority, restart, outage, rejection, and non-claim facts.

#### Scenario: OnixOS consumes replica evidence

r[onix.radicle_replica.evidence.accepted]
- GIVEN positive deployment and negative rejection checks have passed
- WHEN the receipt is exported
- THEN it MUST exclude keys, credentials, raw environments, user-home data, backup authority, private content, and unbounded logs
- AND it MUST deny public-HTTPS-failover, geographic/building-power independence, host-root isolation, private confidentiality, correctness, CI, canonical-ref, and release claims

### Requirement: Replica validation has positive and negative coverage

r[onix.radicle_replica.validation] The replica module and production assignment MUST have positive and negative deterministic checks before deployment or receipt acceptance.

#### Scenario: Focused validation runs

r[onix.radicle_replica.validation.focused]
- GIVEN module, inventory, identity, storage, listener, policy, monitoring, authority, and evidence fixtures
- WHEN focused Nix and Cairn checks run
- THEN every positive fixture MUST pass and every negative fixture MUST fail with its expected diagnostic
