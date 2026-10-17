# Three isolated Nemotron proof workers

## ADDED Requirements

### Requirement: Independent simultaneous replicas r[onix.nemotron-workers.inference]

The campaign MUST run one pinned Nemotron replica per Spark and demonstrate three simultaneously available real model endpoints. Each API MUST remain loopback-only and workstation access MUST use authenticated SSH tunnels. A Docker running flag alone MUST NOT establish inference readiness.

#### Scenario: Three model workers are admitted

- GIVEN all pinned assets are prepared and the original three-rank DeepSeek workload is preserved
- WHEN the temporary cutover starts the replicas
- THEN each host MUST pass memory admission and return an actual model completion through its own tunnel.

### Requirement: Isolated evidence and honest acceptance r[onix.nemotron-workers.isolation]

Every worker MUST use its own editable source snapshot and isolated client state. The complete current Trellis baseline and actual model/tool transcripts MUST be retained. Live source changes MUST be parent-reviewed and independently verified; no new assumption, exemption, narrower input domain, or weakened meaningful contract is allowed. Research output MUST NOT be presented as a verified production feature.

#### Scenario: One candidate is invalid

- GIVEN one worker produces malformed or unverified source
- WHEN that candidate is evaluated
- THEN it MUST NOT alter another worker's source or be accepted on the basis of model claims.

### Requirement: Real repair worker r[onix.nemotron-workers.repair]

One real Nemotron worker MUST investigate current actionable proof defects or meaningful proof gaps. It MUST preserve valid proofs and report a green baseline honestly rather than manufacturing an obligation failure.

#### Scenario: No failing production proof exists

- GIVEN the complete current baseline verifies
- WHEN the repair worker inspects the corpus
- THEN it MUST distinguish contract or trust gaps from solver failures and may report no independently justified repair.

### Requirement: Source-grounded primitive discovery r[onix.nemotron-workers.discovery]

One real Nemotron worker MUST identify concrete bounded primitive opportunities, cite the closest existing source APIs and explain non-duplication and intended contracts. External inspiration and inferred absence MUST be identified as such rather than invented implementation evidence.

#### Scenario: A proposed primitive already exists

- GIVEN the module inventory or source provides an equivalent primitive
- WHEN the discovery output is reviewed
- THEN the proposal MUST be rejected or refined instead of reported as a new gap.

### Requirement: Checked proof composition r[onix.nemotron-workers.composition]

One real Nemotron worker MUST investigate how existing proofs can establish more complex finite-model properties. A proposed connection MUST identify actual module APIs, bridge obligations and trust limitations. Any claimed proof witness MUST pass the existing production verifier against frozen dependencies without new trust escapes.

#### Scenario: A composition has a verified witness

- GIVEN a proof-only candidate composes existing modules
- WHEN independent acceptance runs
- THEN success MUST be grounded in the actual solver output and remain scoped to its explicit finite-model contract.

### Requirement: Restore existing inference ownership r[onix.nemotron-workers.restoration]

The campaign MUST stop only its own replicas/tunnels, restore the original three DeepSeek containers with unchanged identities, images, Config, HostConfig and mount definitions, and prove an actual successful completion after starting workers before the head.

#### Scenario: The model batch ends or fails

- GIVEN the original DeepSeek deployment was temporarily stopped
- WHEN model work ends
- THEN original ownership and working inference MUST be restored before completion.
