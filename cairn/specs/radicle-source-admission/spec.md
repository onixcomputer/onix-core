# Radicle Source Admission Specification

## Purpose

Defines the `radicle-source-admission` capability.

## Requirements

### Requirement: Exact governed source policy r[onix.radicle_source_admission.policy]

Production Radicle source policy MUST admit exactly the existing Bounded Exec RID and the accepted public artifact-auth RID, each bound to its reviewed commit and publication evidence.

#### Scenario: Two accepted sources are admitted

- GIVEN complete publication identities for both repositories
- WHEN production source policy is evaluated
- THEN the exact two canonical public RIDs MUST be admitted.

#### Scenario: Missing, duplicate, malformed, or unknown source fails

- GIVEN either required RID is absent or any entry is duplicate, malformed, or unaccepted
- WHEN policy validation runs
- THEN validation MUST fail.

### Requirement: Single-source derivation r[onix.radicle_source_admission.derivation]

Primary seed, pinned repository, public HTTPS, and desktop replica allowlists MUST derive from one typed ordered production repository set while CI keeps its separate Bounded Exec-only RID.

#### Scenario: All serving roles agree

- GIVEN the accepted two-repository set
- WHEN NixOS settings are lowered
- THEN primary seed, pinning, HTTPS, and replica settings MUST contain the same ordered entries.

#### Scenario: CI does not inherit production expansion

- GIVEN artifact-auth is admitted for source serving
- WHEN CI settings are evaluated
- THEN CI MUST still admit only the Bounded Exec RID.

### Requirement: Positive and negative multi-source validation r[onix.radicle_source_admission.validation]

Repository checks MUST cover accepted two-RID configuration and rejection of missing legacy/new entries, unknown third entries, duplicates, malformed IDs, serving-role mismatch, and CI widening.

#### Scenario: Exact configuration passes

- GIVEN matching two-RID settings and unchanged host identities
- WHEN focused Nix and Nickel checks run
- THEN configuration MUST pass.

#### Scenario: Authority or membership drift fails

- GIVEN a mismatched allowlist, widened CI policy, weakened fingerprint, or changed signed-reference feature
- WHEN validation runs
- THEN it MUST fail with deterministic diagnostics.

### Requirement: Independent two-seed deployment r[onix.radicle_source_admission.deployment]

Aspen and the desktop replica MUST reconcile both admitted repositories while preserving distinct identities, state roots, network exposure, and authority boundaries.

#### Scenario: Both nodes deploy cleanly

- GIVEN signed public repository state and accepted settings
- WHEN each machine is deployed
- THEN both node services and policy reconciliation MUST become healthy without changing node identity.

#### Scenario: Repository import grants no authority

- GIVEN imported signed public refs
- WHEN seed service capabilities are inspected
- THEN no delegate, signing, release, deployment, backup-administration, or canonical-ref authority MUST be added.

### Requirement: Exact endpoint probes r[onix.radicle_source_admission.probes]

Operators MUST verify both reviewed commits independently through Aspen native transport, desktop native transport, and Aspen public HTTPS while confirming undeclared-RID rejection and CI single-RID invariance.

#### Scenario: Every admitted source resolves exactly

- GIVEN fresh bounded clients for each endpoint
- WHEN both reviewed commits are fetched
- THEN each endpoint MUST expose the exact expected object without GitHub fallback.

#### Scenario: Unadmitted source remains blocked

- GIVEN an undeclared RID
- WHEN native policy, HTTPS, and CI admission are queried
- THEN the RID MUST remain rejected.

### Requirement: Typed admission evidence r[onix.radicle_source_admission.evidence]

Onix Core MUST emit typed Nickel/JSON admission evidence with a BLAKE3 sidecar binding policy, identities, deployment, endpoint probes, negative observations, and non-claims.

#### Scenario: Complete evidence passes

- GIVEN matching static and live observations
- WHEN evidence validation runs
- THEN it MUST accept deterministically.

#### Scenario: Missing linkage or overclaim fails

- GIVEN absent publication linkage, endpoint mismatch, widened authority, or weakened non-claims
- WHEN validation runs
- THEN it MUST fail closed.
