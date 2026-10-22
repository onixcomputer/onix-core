# Nemotron Snapshot Repair Specification

## Purpose

Defines the `nemotron-snapshot-repair` capability.

## Requirements

### Requirement: Isolated current inputs r[onix.nemotron-snapshot-repair.isolation]

The campaign MUST preserve unrelated current user work, freeze current proof inputs outside the model's exact edit allowlist, retain actual model/tool evidence, and attribute every verification result to its source identities. Historical evidence MUST remain unchanged.

#### Scenario: A candidate changes a frozen dependency

- GIVEN the campaign has recorded all current proof input identities
- WHEN a candidate modifies a dependency outside the admitted repair scope
- THEN it MUST be rejected rather than integrated or presented as accepted proof evidence.

### Requirement: Real pinned inference r[onix.nemotron-snapshot-repair.runtime]

The campaign MUST use the existing immutable Nemotron base, draft and ARM64 runtime pins, loopback API binding and authenticated SSH access. API availability and actual model output MUST establish inference, not merely container state.

#### Scenario: A replica starts

- GIVEN the original three-rank service is preserved and stopped
- WHEN the prepared pinned replica is launched
- THEN only loopback access MUST be admitted and an actual model response MUST be recorded.

### Requirement: Honest finite-model repair r[onix.nemotron-snapshot-repair.repair]

A real Nemotron session MUST attempt the current actionable snapshot-integrity defect. The replacement MUST use an exact commitment to both input hashes, preserve meaningful tamper postconditions, and add no assumption, exemption, trust escape, restricted input domain or compatibility shim. Documentation MUST distinguish structural consistency from cryptographic authentication.

#### Scenario: Two distinct input pairs are combined

- GIVEN arbitrary pairs of `u64` hashes
- WHEN either component differs
- THEN the executable commitment MUST differ and this property MUST be proved from the implementation rather than assumed.

### Requirement: Independent consumer and proof acceptance r[onix.nemotron-snapshot-repair.acceptance]

Parent acceptance MUST exercise actual public runtime functions, including the recorded high-bit metadata collision, independently run the full production Verus corpus, migrate all active callers and trust accounting, and reject model claims unsupported by those checks.

#### Scenario: The former collision is replayed

- GIVEN a valid snapshot with zero input hashes
- WHEN only metadata changes to `1 << 63`
- THEN both integrity verification entry points MUST reject the modified record while the unmodified record still verifies.

### Requirement: Restore original inference r[onix.nemotron-snapshot-repair.restoration]

The campaign MUST stop only its own model/tunnel resources, restore all original DeepSeek container identities, images, Config, HostConfig and mounts, and prove a successful real completion after workers start before the head.

#### Scenario: Model work finishes or fails

- GIVEN the original three-rank service was temporarily displaced
- WHEN the bounded repair session ends
- THEN original working inference MUST be restored before campaign completion.
