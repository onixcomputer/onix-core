# Canonical Artifact source admission delta

## MODIFIED Requirements

### Requirement: Exact governed source policy r[onix.radicle_source_admission.policy]

Production public policy MUST admit exactly Bounded Exec, artifact-auth compatibility, execution-graph, Choregraph, durable-file-publication, koiTerminal fork, and canonical Artifact, in that order. Private and CI policy MUST remain unchanged. Artifact MUST preserve its existing public identity, one delegate and threshold one.

#### Scenario: Seven public repositories are admitted

- GIVEN canonical Artifact is already public and hosting is explicitly authorized
- WHEN policy is evaluated
- THEN all seven ordered RIDs MUST be admitted without replacing artifact-auth compatibility.

### Requirement: Exact endpoint probes r[onix.radicle_source_admission.probes]

Canonical Artifact acceptance MUST bind independent objects `e41340bec587b6d049b5cc518ec7db925dde84be` and `c932138d880ddf4c2967f4c024b489b5c0022bf1` through fresh credential-free HTTPS Git fetch/readback, exact revision/type/archive identity and rejection probes. A default-main fetch MUST NOT substitute for either object.

#### Scenario: Exact acquisition is distinct from publication

- GIVEN the already-public signed repository and checked/deployed policy
- WHEN fresh clients fetch each exact object
- THEN each expected revision and commit type MUST match and its archive digest MUST be recorded.
- AND unknown RID, private RID, unknown ref and write operations MUST remain rejected.

### Requirement: Typed admission evidence r[onix.radicle_source_admission.evidence]

Fresh Nickel, JSON and BLAKE3 evidence MUST distinguish observed staged/blocked state from accepted deployment/acquisition. Historical receipts MUST remain unchanged. Missing deployed roles, signed identity or endpoint evidence MUST block acceptance and lifecycle archive.

#### Scenario: Undeployed roles are not accepted

- GIVEN any required role or probe is unobserved
- WHEN admission evidence is evaluated
- THEN acceptance MUST fail closed without inventing successful evidence.

### Requirement: Single-source derivation r[onix.radicle_source_admission.derivation]

Primary native, primary HTTPS and managed replica policy MUST derive the same ordered seven public entries from the shared typed catalog, preserving the four private entries and Bounded Exec-only CI.

#### Scenario: Serving roles agree

- GIVEN the additive Artifact admission
- WHEN production settings are lowered
- THEN all public serving roles MUST agree without widening CI.

### Requirement: Positive and negative multi-source validation r[onix.radicle_source_admission.validation]

Focused validators MUST accept exactly seven ordered public entries and reject each missing, unknown, duplicate, private-exposed or role-mismatched entry and any CI expansion.

#### Scenario: Missing Artifact fails

- GIVEN a configuration omitting canonical Artifact
- WHEN either primary or replica validation runs
- THEN validation MUST reject it deterministically.

### Requirement: Independent managed-seed deployment r[onix.radicle_source_admission.deployment]

Only checked, explicitly authorized serving configuration MAY be deployed. Every claimed deployed role MUST reconcile exactly seven public plus four private policies and preserve its node identity. Missing hosts, authority or tooling MUST block that role, not authorize a substitute transport.

#### Scenario: Narrow deployment preserves unrelated state

- GIVEN a scoped hosting grant and checked serving configuration
- WHEN the documented owner deployment runs
- THEN unrelated services, producer governance, CI and source-selection policy MUST remain unchanged.

