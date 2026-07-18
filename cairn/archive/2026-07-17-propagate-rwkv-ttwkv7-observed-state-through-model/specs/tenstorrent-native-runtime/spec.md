## ADDED Requirements

### Requirement: Physical layer-zero state composes through the complete recurrent model

The RWKV harness SHALL provide a deterministic device-free replay that validates the exact accepted observed-layer and state-carry receipts, injects the package-owned physical layer-zero second-token WKV output and post-state, carries the physically perturbed token through CPU layers 1–11, and executes one additional token through all twelve CPU layers and the untied language-model head. The replay SHALL retain independent attention, channel, matrix, and oracle state per layer; preserve token-local `v_first`; record all twelve final-token layer outputs plus complete state, hidden, logits, and top-two ranking; and compare source-FP32, expected-BF16, observed, reset, and transposed-state paths. It SHALL accept only `--evidence-root PATH`, reject evidence or invocation drift, preserve the terminal `unsafe` classification, and expose no process, device, owner-service, or hardware-authorization surface.

A passing replay SHALL establish only device-free structural composition from the accepted physical layer-zero boundary through all twelve layers and model logits. It SHALL NOT claim physical execution of the third-token WKV step, layers 1–11, a wholly device-executed model, hardware-backed generation, serving, throughput, latency, or general P150 compatibility.

r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]

#### Scenario: Physical seed propagates through all twelve layers

- **GIVEN** the exact package-owned unsafe-session evidence and accepted observed-layer/state-carry receipt identities
- **WHEN** token sequence `[1, 2, 2]` is replayed with the physical layer-zero second-token output and post-state
- **THEN** the harness records twelve ordered third-token layer outputs, complete recurrent state, final hidden state, logits, and audited top-two ranking
- **AND** labels only the accepted layer-zero second-token boundary as physical evidence

#### Scenario: Reset and orientation controls remain model-visible

- **GIVEN** identical physically perturbed token-two host and later-layer state
- **WHEN** the layer-zero matrix seed is reset or transposed before the third token
- **THEN** complete state and logits differ from the observed retained-state path by named positive floors
- **AND** the observed path remains closer to expected BF16 than to either control

#### Scenario: Evidence and invocation drift fail closed

- **GIVEN** the package-owned evidence hashes and sole accepted `--evidence-root PATH` argument vector
- **WHEN** a prior receipt, evidence artifact, argument count, argument order, or option name changes
- **THEN** the replay exits unsuccessfully without emitting an accepted receipt
