# Bounded Exec successor source admission delta

## MODIFIED Requirements

### Requirement: Exact governed source policy

r[onix.radicle_source_admission.policy]

Production Radicle public-source policy MUST admit exactly Bounded Exec, `artifact-auth`, `execution-graph`, Choregraph, `durable-file-publication`, the koiTerminal fork, canonical Artifact and the Bounded Exec successor `rad:zG25DRmacxYQcXzZmLKj8tmgYbEG`, in that order. Each entry MUST bind its reviewed revision and publication evidence. The successor MUST bind reviewed commit `9e64b2f429c8f9035a06fe60ace3adbf331c5598`, one delegate and threshold 1 under the OnixOS `bounded-exec-successor-single-delegate-bootstrap` profile, and every receipt relying on it MUST name that profile. The frozen pilot RID MUST stay admitted and served read-only.

#### Scenario: Eight ordered public sources are admitted

- GIVEN complete source identities for all eight repositories
- WHEN production public-source policy is evaluated
- THEN the exact eight canonical public RIDs MUST be admitted in order, with the successor last.

#### Scenario: Missing, duplicate, malformed, private, or unknown source fails

- GIVEN a required RID is absent, including the successor or the frozen pilot, or an entry is duplicate, malformed, private, or unaccepted
- WHEN policy validation runs
- THEN validation MUST fail.

### Requirement: Single-source derivation

r[onix.radicle_source_admission.derivation]

Aspen1 native seeding, Aspen1 public HTTPS, and managed replica seeding MUST derive from one typed ordered production set that includes the successor and keeps the frozen pilot. CI MUST keep its separate single-RID Bounded Exec policy, now bound to the successor.

#### Scenario: All public serving roles agree

- GIVEN the accepted eight-repository set
- WHEN NixOS settings are lowered
- THEN primary seed, HTTPS, and replica settings MUST contain the same ordered public entries, with the successor last.

#### Scenario: CI does not inherit production expansion

- GIVEN the successor is admitted for source serving alongside the frozen pilot
- WHEN CI settings are evaluated
- THEN CI MUST admit only the successor RID and MUST NOT admit the frozen pilot or any other public source.

### Requirement: Positive and negative multi-source validation

r[onix.radicle_source_admission.validation]

Repository checks MUST cover the exact eight-RID configuration. They MUST reject every missing source, unknown addition, duplicate, malformed ID, serving-role mismatch, private exposure, CI widening, weak governance fact, and missing non-claim. Historical receipt checks MUST stay bound to the RID sets they recorded.

#### Scenario: Exact configuration passes

- GIVEN matching eight-RID settings, the successor's bootstrap-profile identity, and unchanged host identities
- WHEN focused Nix and Nickel checks, `nix flake check` and the `aspen1`, `britton-desktop` and `aspen3` toplevels run
- THEN configuration MUST pass.

#### Scenario: Authority or membership drift fails

- GIVEN a list missing the successor or the pilot, a widened CI policy or delegate set, a weakened host fingerprint, private exposure, or a changed signed-reference feature
- WHEN validation runs
- THEN it MUST fail with deterministic diagnostics.

### Requirement: Independent managed-seed deployment

r[onix.radicle_source_admission.deployment]

Aspen1 and managed replicas MUST reconcile all admitted public repositories, including the successor, while preserving distinct identities, state roots, network exposure, private-source separation, and authority boundaries. A host MUST be deployed only when its candidate's closure delta from the running system is limited to this admission.

#### Scenario: Managed seeds serve the successor

- GIVEN signed successor state with accepted settings
- WHEN each seed reconciles policy
- THEN every managed seed MUST expose the reviewed successor commit without changing node identity, and the frozen pilot MUST remain served.

#### Scenario: Repository import grants no authority

- GIVEN imported signed public refs
- WHEN seed service capabilities are inspected
- THEN no delegate, signing, CI, release, deployment, backup-administration, or canonical-reference authority MUST be added.

### Requirement: Exact endpoint probes

r[onix.radicle_source_admission.probes]

Operators MUST verify successor commit `9e64b2f429c8f9035a06fe60ace3adbf331c5598` through each declared native transport and Aspen public HTTPS, including adapter `HEAD` and `main`. They MUST confirm undeclared-RID and write rejection.

#### Scenario: Every admitted transport resolves exactly

- GIVEN fresh bounded clients for each endpoint
- WHEN the successor commit is fetched
- THEN each endpoint MUST expose the expected object and source BLAKE3 without GitHub fallback.

#### Scenario: Unadmitted source or write remains blocked

- GIVEN an undeclared RID or Git write operation
- WHEN native policy or HTTPS admission is queried
- THEN the request MUST remain rejected.

### Requirement: Typed admission evidence

r[onix.radicle_source_admission.evidence]

Onix Core MUST emit typed Nickel and JSON evidence with a BLAKE3 sidecar for the successor. Evidence MUST bind policy, identities, the `bounded-exec-successor-single-delegate-bootstrap` profile with its one delegate and threshold 1, deployment, endpoint probes, single-seed outage drills, negative observations, durable state, runtime-override absence, and non-claims.

#### Scenario: Complete evidence passes

- GIVEN matching static and live observations plus the named bootstrap profile
- WHEN evidence validation runs
- THEN it MUST accept deterministically.

#### Scenario: Missing authority or durable deployment fails

- GIVEN a missing bootstrap-profile name, missing producer identity, runtime-only overrides, endpoint mismatch, widened authority, or weakened non-claims
- WHEN validation runs
- THEN it MUST fail closed.
