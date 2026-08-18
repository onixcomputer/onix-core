## ADDED Requirements

### Requirement: Stateful RWKV-7 token-ID decode reference
r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode] Onix MUST provide a device-free CPU reference that starts from zero state, executes a fixed BOS seed, selects exactly three greedy token IDs, feeds the first two selected IDs back through independently retained state for all twelve layers, and cross-checks every incremental step against zero-state replay without invoking Metalium or a Tenstorrent device.

#### Scenario: Generated tokens are executed with retained state
- GIVEN zero initial attention, channel-mix, matrix, and scalar-oracle state for each layer
- WHEN the fixed three-step decode executes
- THEN BOS selects the first token, the first selected token is the second recurrent input, and the second selected token is the third recurrent input
- AND no layer state is reset, omitted, or shared between those inputs

#### Scenario: Incremental execution matches zero-state replay
- GIVEN the exact processed input prefix at each decode step
- WHEN the incremental path retains prior state and the replay path recomputes that prefix from zero
- THEN final normalized hidden values, full logits, flattened recurrent matrices, top-two rankings, and direct BF16-row head audits agree within named tolerances
- AND every per-layer recurrence oracle remains within its named tolerance
- AND every post-seed retained-state hidden value differs from a same-token zero-state control by more than the named divergence floor

#### Scenario: EOS policy is explicit and bounded
- GIVEN any selected token equals the configured EOS token ID
- WHEN the diagnostic has remaining steps
- THEN EOS observation is recorded and the exact three-step diagnostic continues
- AND the receipt states that this is not normal EOS stopping or text generation

#### Scenario: Stateful receipt is deterministic
- GIVEN the exact pinned checkpoint, BOS seed, step budget, and arithmetic policy
- WHEN the decode harness runs repeatedly
- THEN it emits byte-identical per-step token IDs, input chaining, top-two logits, margins, vector statistics, BLAKE3 fingerprints, replay deviations, retained/reset control deviations, and final state evidence
- AND the receipt records checkpoint identity, dimensions, exact budget, EOS policy, and explicit non-claims

#### Scenario: Stateful evidence is invalid
- GIVEN a wrong checkpoint schema or digest, incomplete layer inventory, state reset, shared state, stale generated-token input, changed token order, replay mismatch, non-finite value, head-audit disagreement, or shortened budget
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing decode receipt
- AND no fallback model, dynamic Python implementation, subprocess, device process, or retry executes

#### Scenario: Stateful evidence remains narrowly scoped
- GIVEN the exact three-step token-ID receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the pinned CPU FP32-from-BF16 state transitions and selected IDs
- AND no decoded text, tokenizer correctness, normal EOS behavior, sampling, arbitrary prompt support, long-context stability, framework parity, P150 parity, repaired-reader completion, or performance is inferred
