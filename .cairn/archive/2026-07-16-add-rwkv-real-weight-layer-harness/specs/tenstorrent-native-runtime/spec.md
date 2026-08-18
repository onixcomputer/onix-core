## ADDED Requirements

### Requirement: Real-weight RWKV-7 layer reference
r[onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer] Onix MUST provide a device-free CPU reference that binds a pinned real RWKV-7 checkpoint, decodes its exact BF16 layer-zero schema, executes at least two fixed tokens through one complete layer with recurrent state carry, and emits deterministic BLAKE3-bound recurrence and layer receipts without invoking Metalium or a Tenstorrent device.

#### Scenario: Pinned checkpoint schema is accepted
- GIVEN the exact reviewed checkpoint revision with matching Nix SHA-256 and runtime BLAKE3 digests
- WHEN the harness decodes the required embedding rows and layer-zero tensors
- THEN every required tensor has the reviewed BF16 dtype, name, orientation, and shape
- AND no implicit transpose, missing tensor, duplicate tensor, or mutable model path is accepted

#### Scenario: Two real tokens exercise one complete layer
- GIVEN zero initial time-mix, channel-mix, and matrix state plus the checkpoint BOS and EOS embedding rows
- WHEN the harness executes layer zero sequentially in CPU FP32
- THEN the second token consumes the first token's carried state and produces finite recurrence vectors, final matrix state, and residual layer output
- AND layer normalization, time mixing, WKV7 recurrence, group normalization, gate correction, channel mixing, and both residual additions are included

#### Scenario: Recurrence orientation is cross-checked
- GIVEN the two-token real-weight recurrence inputs
- WHEN the production matrix update and separately structured scalar oracle evaluate the same state transitions
- THEN their state and output maximum absolute deviations remain within the named FP32 tolerance
- AND a transposed rank update, decay axis, outer product, or readout fails deterministic validation

#### Scenario: Deterministic receipt binds the integration rung
- GIVEN the exact checkpoint and fixed two-token layer execution
- WHEN the harness runs repeatedly
- THEN it emits identical BLAKE3 fingerprints and finite-value statistics for the recurrence inputs, final state, and final layer output
- AND the receipt records the checkpoint revision, content digests, dimensions, token IDs, arithmetic precision, and explicit non-claims

#### Scenario: Checkpoint or numerical evidence is invalid
- GIVEN a wrong digest, dtype, shape, tensor name, non-finite value, incomplete state carry, or recurrence-oracle mismatch
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing receipt
- AND no fallback model, dynamic Python implementation, device process, or retry executes

#### Scenario: Layer evidence remains narrowly scoped
- GIVEN the real-weight layer receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the exact CPU FP32 two-token layer-zero execution and recurrence mapping
- AND no full-model logits, generated token, text generation, P150 parity, repaired-reader completion, performance, or general RWKV correctness is inferred
