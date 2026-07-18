## Why

The accepted observed-layer replay proves that the physical second-token WKV output composes through the same-token CPU suffix, but it does not yet prove that the physical post-state is structurally usable by a later recurrent step. Stateful model and generation integration require that next-step boundary before another hardware session can be justified.

## What Changes

- Preserve the accepted observed-layer receipt unchanged while adding a separate deterministic state-carry replay.
- Seed layer zero's next token with the exact physical post-state and the host-side attention/channel state produced by the observed second-token composition.
- Run one additional CPU WKV recurrence through the exact BF16 transport boundary, then complete the shared attention and channel-mix suffix.
- Compare source-FP32, expected-BF16, observed-physical-state, reset-state, and transposed-state control paths with complete-vector fingerprints and deviations.
- Add positive, deterministic, malformed-input, reset-discrimination, closure, and regression checks without opening a device or authorizing a hardware process.

## Capabilities

### New Capabilities

- `rwkv_ttwkv7_observed_state_carry`: Deterministic evidence that the exact physical WKV post-state can seed a subsequent layer-zero recurrent step and remains distinguishable from reset state.

### Modified Capabilities

- `tenstorrent-native-runtime`: Extends the device-free RWKV integration ladder from same-token hybrid composition to one-step recurrent carry while preserving the immutable unsafe session classification.

## Impact

- Adds a separate fixed-invocation Rust state-carry harness and Nix check to `pkgs/rwkv-layer-harness`.
- Extends the shared functional core only where needed to expose deterministic post-token host state.
- Changes no ttWKV7 kernel, device runner, owner service, hardware runbook, authorization, or physical-device state.
- Does not establish a physical third-token WKV execution, a wholly device-executed layer, all-layer state carry, token generation, serving, throughput, or latency.
