# Nemotron Nix Version Specification

## Purpose

Defines the `nemotron-nix-version` capability.

## Requirements

### Requirement: Source-bound isolated inputs
r[onix.nemotron-nix-version.isolation]

The campaign MUST freeze current proof inputs, preserve unrelated changes and historical evidence, and attribute every tool and verification result to actual source identities. Only reviewed in-scope changes may be integrated.

#### Scenario: A frozen input changes

- GIVEN a recorded source snapshot and exact model edit allowlist
- WHEN a candidate changes another input
- THEN the candidate MUST be rejected rather than credited as a verified repair.

### Requirement: Actual pinned inference
r[onix.nemotron-nix-version.runtime]

The campaign MUST use the existing immutable Nemotron runtime/base/draft pins, loopback API binding and authenticated workstation tunnel. A real response MUST establish inference; container state alone is insufficient.

#### Scenario: The replica becomes available

- GIVEN preserved original GPU ownership and the prepared pinned launcher
- WHEN the temporary replica starts
- THEN an actual completion MUST be recorded before model work is credited.

### Requirement: Honest full-domain repair
r[onix.nemotron-nix-version.repair]

A real bounded Nemotron worker MUST attempt the current comparison defect on isolated source. No new trust escape, artificial numeric limit, input-domain restriction, weaker meaningful postcondition or compatibility alias may establish acceptance. Nix's signed-32-bit numeric classification and lexical overflow behavior MUST be preserved; unlimited input length MUST NOT be mistaken for arbitrary-precision numeric ordering. Rejected model work and independent corrections MUST remain distinguishable.

#### Scenario: A model reports success without a passing verifier

- GIVEN actual model edits and tool receipts
- WHEN the final changed source lacks a successful independent solver result
- THEN it MUST remain an unaccepted candidate.

### Requirement: Actual ordering and complete acceptance
r[onix.nemotron-nix-version.acceptance]

The integrated comparison MUST implement full-domain Nix component ordering for the inspected Linux C-locale, 32-bit-int profile with ordinary executable/spec proofs. Acceptance MUST exercise actual Nix agreement where evaluator strings faithfully represent inputs, retain the byte-domain/oracle boundary, prove progress for arbitrary bytes, and check integer-boundary/overflow text ordering, unlimited leading zeros, `pre` and consumers. Full production Verus, runtime gates, current inventories and documentation MUST agree.

#### Scenario: Long numeric components differ beyond machine integer width

- GIVEN two distinct numeric runs larger than `u64`
- WHEN actual Nix orders them distinctly
- THEN the runtime comparator MUST return the same ordering rather than saturating both values to equality.

### Requirement: Restore original inference ownership
r[onix.nemotron-nix-version.restoration]

The campaign MUST remove only its own replica/tunnel state, restore all original container identities and definitions, start workers before the head, and prove an actual successful completion on success or failure.

#### Scenario: The bounded attempt ends

- GIVEN the displaced original three-rank service
- WHEN model work ends or fails
- THEN the original containers MUST be restored unchanged and real inference MUST succeed.
