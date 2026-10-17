# Nemotron 3.5 Spark verification workflow

## ADDED Requirements

### Requirement: Honest public-model scope r[onix.nemotron35.scope]

The workflow MUST identify NVIDIA's released NVFP4 checkpoint separately from Reasonable's unreleased fine-tune and MUST NOT claim the article's training or benchmark results. It MUST use native Cairn artifacts and retain observed runtime evidence and usage instructions.

#### Scenario: Reasonable assets are unavailable

- GIVEN no attributable public fine-tuned checkpoint, tlaverus corpus or evaluation harness is available
- WHEN the operator selects public-model-plus-Verus scope
- THEN the workflow MUST run that scope explicitly without fabricating assets or scores.

### Requirement: Safe pinned single-Spark inference r[onix.nemotron35.inference]

The launcher MUST pin the Linux ARM64 runtime by digest and both model snapshots by immutable revision, run the actual Nemotron 3.5 Super VL NVFP4 language model on GB10 with reasoning and structured tool support, bind only loopback, and refuse insufficient free memory without stopping unrelated workloads. It MUST NOT expose secrets, replace existing DeepSeek containers, or enroll/reimage hosts.

#### Scenario: Existing workloads occupy memory

- GIVEN the existing DeepSeek model occupies approximately 95 GiB per Spark
- WHEN the new launcher starts without a separately authorized cutover
- THEN admission MUST fail without removing or stopping the existing container.

#### Scenario: The model is admitted

- GIVEN pinned snapshots and an available GB10
- WHEN the standalone server starts
- THEN real inference and structured tool calls MUST succeed through the authenticated SSH tunnel.

### Requirement: Trellis verifier-assisted proof completion r[onix.nemotron35.verus]

The workflow MUST reuse Trellis's production Verus package and a meaningful existing proof in an isolated work directory, demonstrate an initially unsolved obligation, run a real model/tool session, and independently verify the final candidate while preserving the theorem/specification scaffold and rejecting new trust escapes. It MUST NOT edit the source Trellis checkout or misrepresent the demo as Reasonable's unpublished evaluation gate.

#### Scenario: The model claims success without a valid proof

- GIVEN an absent, malformed, scaffold-modified, trust-expanded or verifier-failing candidate
- WHEN the final independent check runs
- THEN the workflow MUST fail instead of reporting a proved theorem.

### Requirement: Temporary cutover restoration r[onix.nemotron35.restoration]

The authorized verification MUST preserve and restore all three existing DeepSeek container identities and configurations after stopping the new model. Restored inference MUST be exercised before completion. No reboot, permanent model replacement, gateway rewrite or mesh configuration change is authorized.

#### Scenario: Verification ends

- GIVEN the three original DeepSeek ranks were temporarily stopped
- WHEN the new model is stopped
- THEN the original workers MUST restart before the head and restored inference MUST succeed.
