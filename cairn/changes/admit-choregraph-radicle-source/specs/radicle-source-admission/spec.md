# Radicle Source Admission Specification Delta

## MODIFIED Requirements

### Requirement: Exact governed source policy r[onix.radicle_source_admission.policy]

Production Radicle public-source policy MUST admit exactly Bounded Exec, `artifact-auth`, `execution-graph`, and Choregraph. Each entry MUST bind its reviewed revision and publication evidence.

#### Scenario: Four accepted public sources are admitted

- GIVEN complete source identities for all four repositories
- WHEN production public-source policy is evaluated
- THEN the exact four canonical public RIDs MUST be admitted.

#### Scenario: Missing, duplicate, malformed, private, or unknown source fails

- GIVEN a required RID is absent or an entry is duplicate, malformed, private, or unaccepted
- WHEN policy validation runs
- THEN validation MUST fail.

### Requirement: Single-source derivation r[onix.radicle_source_admission.derivation]

Primary seed, public HTTPS, and desktop replica public-source lists MUST derive from one typed ordered production set. CI MUST keep its separate Bounded Exec-only RID.

#### Scenario: All public serving roles agree

- GIVEN the accepted four-repository set
- WHEN NixOS settings are lowered
- THEN primary seed, HTTPS, and replica settings MUST contain the same ordered public entries.

#### Scenario: CI does not inherit production expansion

- GIVEN Choregraph is admitted for source serving
- WHEN CI settings are evaluated
- THEN CI MUST still admit only the Bounded Exec RID.

### Requirement: Positive and negative multi-source validation r[onix.radicle_source_admission.validation]

Repository checks MUST cover the exact four-RID configuration. They MUST reject every missing source, unknown addition, duplicate, malformed ID, serving-role mismatch, private exposure, and CI widening.

#### Scenario: Exact configuration passes

- GIVEN matching four-RID settings and unchanged host identities
- WHEN focused Nix and Nickel checks run
- THEN configuration MUST pass.

#### Scenario: Authority or membership drift fails

- GIVEN a mismatched list, widened CI policy, weakened fingerprint, private exposure, or changed signed-reference feature
- WHEN validation runs
- THEN it MUST fail with deterministic diagnostics.

### Requirement: Independent two-seed deployment r[onix.radicle_source_admission.deployment]

Aspen and the desktop replica MUST reconcile all admitted public repositories while preserving distinct identities, state roots, network exposure, private-source separation, and authority boundaries.

#### Scenario: Both nodes serve Choregraph

- GIVEN signed public repository state and accepted settings
- WHEN each seed reconciles policy
- THEN both nodes MUST expose the exact reviewed object without changing node identity.

#### Scenario: Repository import grants no authority

- GIVEN imported signed public refs
- WHEN seed service capabilities are inspected
- THEN no delegate, signing, release, deployment, backup-administration, or canonical-reference authority MUST be added.

### Requirement: Exact endpoint probes r[onix.radicle_source_admission.probes]

Operators MUST verify the reviewed Choregraph revision through Aspen native transport, desktop native transport, and Aspen public HTTPS. They MUST confirm undeclared-RID and write rejection.

#### Scenario: Every admitted transport resolves exactly

- GIVEN fresh bounded clients for each endpoint
- WHEN the reviewed revision is fetched
- THEN each endpoint MUST expose the expected object and source BLAKE3 without GitHub fallback.

#### Scenario: Unadmitted source or write remains blocked

- GIVEN an undeclared RID or Git write operation
- WHEN native policy or HTTPS admission is queried
- THEN the request MUST remain rejected.

### Requirement: Typed admission evidence r[onix.radicle_source_admission.evidence]

Onix Core MUST emit typed Nickel and JSON evidence with a BLAKE3 sidecar. Evidence MUST bind policy, identities, deployment, endpoint probes, producer authority, negative observations, durable state, and non-claims.

#### Scenario: Complete evidence passes

- GIVEN matching static and live observations plus accepted producer authority
- WHEN evidence validation runs
- THEN it MUST accept deterministically.

#### Scenario: Missing authority or durable deployment fails

- GIVEN missing operator authority, runtime-only policy, endpoint mismatch, widened authority, or weakened non-claims
- WHEN validation runs
- THEN it MUST fail closed.
