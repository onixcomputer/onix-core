## ADDED Requirements

### Requirement: Pinned RWKV-7 tokenizer and text reference
r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text] Onix MUST provide a device-free CPU reference that binds the pinned checkpoint's exact tokenizer, model, and generation-configuration artifacts, validates and implements its byte-level longest-prefix vocabulary, reports their conflicting BOS/EOS IDs, applies one fixed chat prompt with generation-config BOS ID `0`, performs bounded retained-state greedy generation with generation-config EOS ID `0`, and emits deterministic token, byte, text, state, and replay evidence without invoking Metalium or a Tenstorrent device.

#### Scenario: Exact tokenizer authority is accepted
- GIVEN the vocabulary, tokenizer configuration, added-token map, special-token map, tokenizer implementation, model configuration, and generation configuration at the exact accepted model revision
- WHEN the tokenizer harness loads those artifacts
- THEN every artifact matches its fixed Nix SHA-256 and runtime BLAKE3 identity
- AND the receipt distinguishes model-config BOS/EOS IDs `1/2`, tokenizer BOS ID `0`, ordinary byte-vocabulary EOS ID `261`, tokenizer-wrapper EOS added-special ID `65,530`, generation-config BOS/EOS IDs `0/0`, and byte vocabulary rows `1` through `65,529`

#### Scenario: Vocabulary and configuration are malformed
- GIVEN a wrong digest, missing or duplicate ID, duplicate token bytes, wrong declared byte length, malformed literal escape, noncontiguous row, changed special ID, changed model or generation ID, or tokenizer EOS text that does not encode to exactly ID `261`
- WHEN tokenizer validation runs
- THEN it returns an error before publishing a tokenizer or text receipt
- AND no fallback vocabulary, dynamic download, subprocess, or device path executes

#### Scenario: Byte tokenizer matches the pinned reference
- GIVEN fixed ASCII, multibyte Unicode, overlapping-token, control-byte, ordinary EOS, wrapper BOS/EOS, and chat-template fixtures
- WHEN the pure Rust tokenizer and pinned upstream reference encode and decode them
- THEN both select the same greedy longest-prefix token IDs and reconstruct the same exact bytes
- AND invalid IDs, invalid final UTF-8, and unsupported literal syntax fail deterministically

#### Scenario: Fixed chat prompt generates bounded text
- GIVEN zero initial state and the exact configured chat template applied to the fixed user message
- WHEN the argument-free text harness reproduces wrapper BOS ID `0` and wrapper EOS ID `65,530` in the rendered prompt and greedily generates within the named budget
- THEN each selected non-EOS ID is decoded to exact token bytes and fed back through independently retained state for all twelve layers
- AND generation stops immediately if generation-config EOS ID `0` is selected
- AND ordinary byte-vocabulary EOS ID `261` and wrapper EOS ID `65,530` are recorded but do not silently replace the generation stop policy

#### Scenario: Text execution matches zero-state replay
- GIVEN the complete prompt and generated-input prefix at each generation step
- WHEN the incremental path retains state and the replay path recomputes that prefix from zero
- THEN final hidden values, logits, recurrent matrices, top-two rankings, and direct BF16-row head audits agree within named tolerances
- AND post-prefix retained execution differs from a same-token zero-state control by more than the named divergence floor

#### Scenario: Tokenizer and text receipt is deterministic
- GIVEN the exact checkpoint, tokenizer artifacts, prompt, chat template, greedy policy, arithmetic policy, and generation budget
- WHEN the text harness runs repeatedly
- THEN it emits byte-identical prompt text and IDs, generated IDs, per-token bytes, decoded UTF-8 text, EOS reason, logits, margins, vector statistics, BLAKE3 fingerprints, replay deviations, and final state evidence
- AND the receipt records all model and tokenizer identities plus explicit non-claims

#### Scenario: Text evidence remains narrowly scoped
- GIVEN the fixed-prompt text receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to exact CPU FP32-from-BF16 greedy execution and tokenizer behavior for the pinned artifacts and prompt
- AND no sampling, arbitrary prompt interface, long-context stability, framework numerical parity, P150 parity, ttWKV7 parity, repaired-reader completion, linguistic quality, or performance is inferred

## MODIFIED Requirements

### Requirement: Real-weight RWKV-7 greedy token reference
r[onix.tenstorrent.native_runtime.rwkv_lab.greedy_token] Onix MUST provide a device-free CPU reference that binds the pinned real RWKV-7 checkpoint, executes the model-config BOS/EOS prefix `[1, 2]` through all twelve layers with independent carried state and reviewed cross-layer value mixing, applies the final model normalization and untied language-model head, and emits one deterministic greedy token receipt without invoking Metalium or a Tenstorrent device.

#### Scenario: Complete model schema is accepted
- GIVEN the exact reviewed checkpoint revision with matching Nix SHA-256 and runtime BLAKE3 digests
- WHEN the harness decodes all twelve layers, layer-indexed value LoRA tensors, final normalization, and language-model head
- THEN every required tensor has the reviewed BF16 dtype, name, orientation, and shape
- AND layer-zero-only tensors, later-layer-only tensors, the embedding table, and the untied head are not substituted for one another

#### Scenario: Fixed prefix carries independent state through every layer
- GIVEN zero initial attention, channel-mix, matrix, and oracle state for each of twelve layers
- WHEN model-config BOS/EOS IDs `1` and `2` execute sequentially through the complete model
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
- AND the receipt records the model-config prefix, generated token ID, top-two logits, greedy margin, per-layer deviations, checkpoint identity, dimensions, arithmetic precision, and explicit tokenizer/generation non-claims

#### Scenario: Complete-model evidence is invalid
- GIVEN a wrong digest, dtype, shape, tensor name, layer count, state owner, value anchor, value-LoRA activation, final norm placement, head orientation, non-finite value, recurrence mismatch, or head-audit disagreement
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing token receipt
- AND no fallback model, dynamic Python implementation, device process, subprocess, or retry executes

#### Scenario: Greedy-token evidence remains narrowly scoped
- GIVEN the complete-model token receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the exact CPU FP32-from-BF16 checkpoint, model-config prefix, logits, and selected token ID
- AND model-config IDs `1` and `2` are not represented as tokenizer or generation-config BOS/EOS IDs
- AND no decoded text, generated-token recurrent step, sampling, multi-token generation, framework bit parity, P150 parity, repaired-reader completion, performance, or general RWKV correctness is inferred

### Requirement: Stateful RWKV-7 token-ID decode reference
r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode] Onix MUST provide a device-free CPU reference that starts from zero state, executes model-config BOS seed ID `1`, selects exactly three greedy token IDs, feeds the first two selected IDs back through independently retained state for all twelve layers, and cross-checks every incremental step against zero-state replay without invoking Metalium or a Tenstorrent device.

#### Scenario: Generated tokens are executed with retained state
- GIVEN zero initial attention, channel-mix, matrix, and scalar-oracle state for each layer
- WHEN the fixed three-step decode executes from model-config BOS ID `1`
- THEN the seed selects the first token, the first selected token is the second recurrent input, and the second selected token is the third recurrent input
- AND no layer state is reset, omitted, or shared between those inputs

#### Scenario: Incremental execution matches zero-state replay
- GIVEN the exact processed input prefix at each decode step
- WHEN the incremental path retains prior state and the replay path recomputes that prefix from zero
- THEN final normalized hidden values, full logits, flattened recurrent matrices, top-two rankings, and direct BF16-row head audits agree within named tolerances
- AND every per-layer recurrence oracle remains within its named tolerance
- AND every post-seed retained-state hidden value differs from a same-token zero-state control by more than the named divergence floor

#### Scenario: Model-config stop policy is explicit and bounded
- GIVEN any selected token equals model-config EOS ID `2`
- WHEN the diagnostic has remaining steps
- THEN stop-ID observation is recorded and the exact three-step diagnostic continues
- AND the receipt states that model-config EOS ID `2` differs from ordinary byte EOS ID `261`, wrapper EOS ID `65,530`, and generation-config EOS ID `0`, so this is not normal generation-config stopping or text generation

#### Scenario: Stateful receipt is deterministic
- GIVEN the exact pinned checkpoint, model-config seed, step budget, and arithmetic policy
- WHEN the decode harness runs repeatedly
- THEN it emits byte-identical per-step token IDs, input chaining, top-two logits, margins, vector statistics, BLAKE3 fingerprints, replay deviations, retained/reset control deviations, and final state evidence
- AND the receipt records checkpoint identity, dimensions, exact budget, model-config stop policy, and explicit tokenizer/generation non-claims

#### Scenario: Stateful evidence is invalid
- GIVEN a wrong checkpoint schema or digest, incomplete layer inventory, state reset, shared state, stale generated-token input, changed token order, replay mismatch, non-finite value, head-audit disagreement, or shortened budget
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing decode receipt
- AND no fallback model, dynamic Python implementation, subprocess, device process, or retry executes

#### Scenario: Stateful evidence remains narrowly scoped
- GIVEN the exact three-step fixed-ID receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the pinned CPU FP32-from-BF16 state transitions and selected IDs
- AND model-config seed ID `1` and stop ID `2` are not represented as tokenizer or generation-config BOS/EOS IDs
- AND no decoded text, tokenizer correctness, normal EOS behavior, sampling, arbitrary prompt support, long-context stability, framework parity, P150 parity, repaired-reader completion, or performance is inferred
