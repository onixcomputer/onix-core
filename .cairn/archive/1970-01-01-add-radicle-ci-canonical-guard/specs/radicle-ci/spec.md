# Radicle CI Canonical Guard Specification

## ADDED Requirements

### Requirement: Signed machine-readable status

r[onix.radicle_ci.canonical_guard.status] The non-delegate CI publisher MUST place a closed machine-readable status payload in its signed exact-revision patch comment, binding the accepted policy, RID, patch/revision, check name, job/object, disposition, artifact, event/result identities, and bounded non-claim.

#### Scenario: Exact successful status is materialized

- GIVEN an admitted patch event and matching successful result
- WHEN the publisher renders the status comment
- THEN the payload MUST be deterministic, parse as the closed status schema, and preserve every exact identity.

#### Scenario: Status drift is rejected

- GIVEN malformed JSON, an unknown field, wrong policy/RID/revision/check/job/object/artifact, failed disposition, wrong author, or weakened non-claim
- WHEN guard materialization runs
- THEN the status MUST NOT contribute to canonical admission.

### Requirement: Pure canonical guard decision

r[onix.radicle_ci.canonical_guard.core] onix-core MUST derive a deterministic guarded compare-and-swap decision only when the typed event/result, signed bot status, Valence admission receipt, exact live patch revision, threshold unique delegate accept reviews, threshold verified `parent` signed refs naming the candidate, current canonical predecessor, and candidate descendant all agree with the typed policy.

#### Scenario: Complete exact-revision evidence is admitted

- GIVEN a non-delegate bot, succeeded zero-exit event/result, matching signed status, threshold exact-revision delegate accepts, the same threshold of cryptographically verified delegate `parent` signed refs naming the candidate, a current expected predecessor, and a descendant candidate
- WHEN the pure guard runs
- THEN it MUST emit a BLAKE3-bound decision naming only the exact target ref, expected-old OID, candidate OID, and external operator claim boundary.

#### Scenario: Incomplete or stale evidence is denied

- GIVEN any malformed, failed, timed-out, stale-policy, wrong-bot, wrong-revision, duplicate-approval, below-review-threshold, below-signed-ref-threshold, wrong signed candidate, weakened signed-ref feature, bot-delegate, non-descendant, stale-canonical, weakened-boundary, or tampered-receipt fact
- WHEN the pure guard runs
- THEN it MUST return deterministic diagnostics and no executable decision.

### Requirement: Preview-first atomic compare-and-swap shell

r[onix.radicle_ci.canonical_guard.shell] The operator shell MUST require explicit capability paths, load the exact built-in patch state from one selected Radicle repository, default to preview, and use an expected-old atomic compare-and-swap only after pure admission and explicit `--execute`.

#### Scenario: Preview is effect-free

- GIVEN complete valid facts without `--execute`
- WHEN the shell runs
- THEN it MUST report an admitted preview without changing any Git ref, signed ref, COB, policy, lifecycle file, or external state.

#### Scenario: Concurrent or escaping mutation fails closed

- GIVEN a changed expected-old ref, absent candidate object, non-descendant candidate, escaping path, unknown/duplicate flag, or mismatched repository RID
- WHEN the shell prepares or executes
- THEN it MUST return nonzero and MUST NOT overwrite the newer canonical ref.

### Requirement: Least-authority deployment boundary

r[onix.radicle_ci.canonical_guard.authority] The canonical guard MUST remain an explicit operator capability and MUST NOT grant production-storage or canonical-ref access to the CI bot, credentialless runner, seed services, or Valence.

#### Scenario: Existing services remain non-authoritative

- GIVEN the evaluated NixOS CI services
- WHEN service users, hardening, inaccessible paths, and invoked subcommands are inspected
- THEN no bot/runner service MUST invoke the guard or gain write access to production Radicle storage.

#### Scenario: Unsupported enforcement claim is rejected

- GIVEN the package, signed status, admission receipt, or execution receipt
- WHEN its claim boundary is evaluated
- THEN it MUST NOT claim protocol-enforced mandatory CI, bypass-proof delegates, Radicle merge semantics, seed convergence, CI correctness, or release readiness.

### Requirement: Guard validation matrix

r[onix.radicle_ci.canonical_guard.validation] The repository MUST retain positive and negative core, status, live-materialization, compare-and-swap, Nickel, Nix evaluation, and authority-boundary tests before lifecycle acceptance.

#### Scenario: Focused validation passes

- GIVEN the completed change
- WHEN Rust tests/Clippy, policy fixtures/freshness, focused flake checks, Cairn gates/validation, and host evaluation checks run
- THEN every selected check MUST pass and evidence MUST record that production refs and live CI scope were unchanged.
