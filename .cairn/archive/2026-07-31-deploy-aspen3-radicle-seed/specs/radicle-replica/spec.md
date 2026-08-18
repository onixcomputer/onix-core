## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Seed identities remain distinct

r[onix.radicle_replica.identity_distinct] Each persistent Radicle seed MUST use a different machine-scoped node identity.

#### Scenario: Production seed fingerprints are compared

r[onix.radicle_replica.identity_distinct.production]
- GIVEN the Aspen1, `britton-desktop`, and `aspen3` production settings
- WHEN focused replica validation compares their pinned fingerprints
- THEN all three fingerprints MUST be unique
- AND a duplicate fingerprint MUST fail validation before deployment
