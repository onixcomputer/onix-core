## ADDED Requirements

### Requirement: Real-weight RWKV-7 greedy token reference
r[onix.tenstorrent.native_runtime.rwkv_lab.greedy_token] Onix MUST provide a device-free CPU reference that binds the pinned real RWKV-7 checkpoint, executes the fixed BOS/EOS prefix through all twelve layers with independent carried state and reviewed cross-layer value mixing, applies the final model normalization and untied language-model head, and emits one deterministic greedy token receipt without invoking Metalium or a Tenstorrent device.

#### Scenario: Complete model schema is accepted
- GIVEN the exact reviewed checkpoint revision with matching Nix SHA-256 and runtime BLAKE3 digests
- WHEN the harness decodes all twelve layers, layer-indexed value LoRA tensors, final normalization, and language-model head
- THEN every required tensor has the reviewed BF16 dtype, name, orientation, and shape
- AND layer-zero-only tensors, later-layer-only tensors, the embedding table, and the untied head are not substituted for one another

#### Scenario: Fixed prefix carries independent state through every layer
- GIVEN zero initial attention, channel-mix, matrix, and oracle state for each of twelve layers
- WHEN BOS and EOS execute sequentially through the complete model
- THEN every layer carries only its own first-token state into the second token
- AND state is neither reset between tokens nor shared between layers

#### Scenario: Token-local value anchor crosses layers
- GIVEN one prefix token entering layer zero
- WHEN its value projections pass through all twelve layers
- THEN layer zero establishes that token's `v_first`
- AND layers one through eleven interpolate their projected value toward the same token-local anchor using sigmoid of the reviewed value LoRA
- AND the anchor is recomputed at layer zero rather than reused across prefix tokens

#### Scenario: Recurrence and language-model head are cross-checked
- GIVEN finite all-layer hidden and recurrent values for the fixed prefix
- WHEN production recurrence, final normalization, production head projection, scalar recurrence oracles, and direct BF16-row head audit execute
- THEN every per-layer recurrence deviation remains within the named FP32 tolerance
- AND production and direct head paths agree on the greedy token and its logit within tolerance
- AND transposed recurrence or head orientation fails deterministic validation

#### Scenario: Deterministic receipt binds one greedy token
- GIVEN the exact checkpoint and fixed complete-model execution
- WHEN the harness runs repeatedly
- THEN it emits byte-identical BLAKE3 fingerprints and finite statistics for final hidden values, logits, and all recurrent states
- AND the receipt records the prefix, generated token ID, top-two logits, greedy margin, per-layer deviations, checkpoint identity, dimensions, arithmetic precision, and explicit non-claims

#### Scenario: Complete-model evidence is invalid
- GIVEN a wrong digest, dtype, shape, tensor name, layer count, state owner, value anchor, value-LoRA activation, final norm placement, head orientation, non-finite value, recurrence mismatch, or head-audit disagreement
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing token receipt
- AND no fallback model, dynamic Python implementation, device process, subprocess, or retry executes

#### Scenario: Greedy-token evidence remains narrowly scoped
- GIVEN the complete-model token receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the exact CPU FP32-from-BF16 checkpoint, fixed prefix, logits, and selected token ID
- AND no decoded text, generated-token recurrent step, sampling, multi-token generation, framework bit parity, P150 parity, repaired-reader completion, performance, or general RWKV correctness is inferred
