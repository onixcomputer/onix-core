# Radicle Source Admission Reconciliation Delta

## MODIFIED Requirements

### Requirement: Exact governed source policy

r[onix.radicle_source_admission.policy]

Production Radicle public-source policy MUST admit exactly Bounded Exec, `artifact-auth`, `execution-graph`, Choregraph, and `durable-file-publication`. Each entry MUST bind its reviewed revision and publication evidence.

#### Scenario: Five accepted public sources are admitted

- GIVEN complete source identities for all five repositories
- WHEN production public-source policy is evaluated
- THEN the exact five canonical public RIDs MUST be admitted.

#### Scenario: Missing, duplicate, malformed, private, or unknown source fails

- GIVEN a required RID is absent or an entry is duplicate, malformed, private, or unaccepted
- WHEN policy validation runs
- THEN validation MUST fail.

### Requirement: Single-source derivation

r[onix.radicle_source_admission.derivation]

Aspen1 native seeding, Aspen1 public HTTPS, and managed replica seeding MUST derive from one typed ordered production set. CI MUST keep its separate Bounded Exec-only RID.

#### Scenario: All public serving roles agree

- GIVEN the accepted five-repository set
- WHEN NixOS settings are lowered
- THEN primary seed, HTTPS, and replica settings MUST contain the same ordered public entries.

#### Scenario: CI does not inherit production expansion

- GIVEN Choregraph and `durable-file-publication` are admitted for source serving
- WHEN CI settings are evaluated
- THEN CI MUST still admit only the Bounded Exec RID.

### Requirement: Positive and negative multi-source validation

r[onix.radicle_source_admission.validation]

Repository checks MUST cover the exact five-RID configuration. They MUST reject every missing source, unknown addition, duplicate, malformed ID, serving-role mismatch, private exposure, CI widening, weak governance fact, and missing non-claim.

#### Scenario: Exact configuration passes

- GIVEN matching five-RID settings, accepted producer identities, and unchanged host identities
- WHEN focused Nix and Nickel checks run
- THEN configuration MUST pass.

#### Scenario: Authority or membership drift fails

- GIVEN a mismatched list, widened CI policy, weakened producer threshold, weakened host fingerprint, private exposure, or changed signed-reference feature
- WHEN validation runs
- THEN it MUST fail with deterministic diagnostics.

### Requirement: Independent managed-seed deployment

r[onix.radicle_source_admission.deployment]

Aspen1 and managed replicas MUST reconcile all admitted public repositories while preserving distinct identities, state roots, network exposure, private-source separation, and authority boundaries.

#### Scenario: Managed seeds serve both concurrent admissions

- GIVEN signed Choregraph and `durable-file-publication` state with accepted settings
- WHEN each seed reconciles policy
- THEN every managed seed MUST expose both exact reviewed objects without changing node identity.

#### Scenario: Repository import grants no authority

- GIVEN imported signed public refs
- WHEN seed service capabilities are inspected
- THEN no delegate, signing, CI, release, deployment, backup-administration, or canonical-reference authority MUST be added.

### Requirement: Exact endpoint probes

r[onix.radicle_source_admission.probes]

Operators MUST verify the reviewed Choregraph revision and `durable-file-publication` commit through each declared native transport and Aspen public HTTPS. They MUST confirm undeclared-RID and write rejection.

#### Scenario: Every admitted transport resolves exactly

- GIVEN fresh bounded clients for each endpoint
- WHEN each reviewed revision is fetched
- THEN each endpoint MUST expose the expected object and source BLAKE3 without GitHub fallback.

#### Scenario: Unadmitted source or write remains blocked

- GIVEN an undeclared RID or Git write operation
- WHEN native policy or HTTPS admission is queried
- THEN the request MUST remain rejected.

### Requirement: Typed admission evidence

r[onix.radicle_source_admission.evidence]

Onix Core MUST emit typed Nickel and JSON evidence with a BLAKE3 sidecar. Evidence MUST bind policy, identities, deployment, endpoint probes, producer governance, negative observations, durable state, runtime-override absence, and non-claims.

#### Scenario: Complete evidence passes

- GIVEN matching static and live observations plus accepted producer authority
- WHEN evidence validation runs
- THEN it MUST accept deterministically.

#### Scenario: Missing authority or durable deployment fails

- GIVEN missing producer identity, runtime-only overrides, endpoint mismatch, widened authority, or weakened non-claims
- WHEN validation runs
- THEN it MUST fail closed.

## ADDED Requirements

### Requirement: Concurrent admission integration preserves both histories

r[onix.radicle_source_admission.concurrent_integration]

A reconciliation merge MUST preserve current canonical history and the reviewed `durable-file-publication` admission history as parents. It MUST NOT rewrite either line or remove an accepted source.

#### Scenario: Reviewed merge preserves both admissions

- GIVEN current canonical Choregraph admission and reviewed durable-publication admission
- WHEN the reconciliation merge is constructed
- THEN both accepted histories MUST be ancestors
- AND the resulting policy MUST contain both RIDs.

#### Scenario: Reconciliation drops or rewrites a source

- GIVEN a candidate that omits one parent, one RID, or one evidence package
- WHEN integration review runs
- THEN integration MUST fail.
