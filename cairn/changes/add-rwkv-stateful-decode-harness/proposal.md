# Change: Add a stateful RWKV-7 decode harness

## Why

The accepted greedy-token rung selects one token from a fixed prefix but deliberately does not execute that token as a recurrent input. It therefore does not prove that all twelve attention, channel-mix, matrix, and oracle states can be retained across generated-token steps. A bounded incremental-versus-replay comparison is the smallest device-free discriminator before tokenizer or device integration.

## What Changes

- Refactor the pure all-layer core into explicit zero-state initialization, one-token transition, and deterministic finalization without changing existing layer or one-token receipts.
- Add a fixed BOS-seeded, three-step greedy diagnostic that feeds the first two selected token IDs back through retained per-layer state.
- Continue for the exact diagnostic budget even if EOS is selected, while recording EOS observation and explicitly denying normal stop-policy or text-generation claims.
- Replay each processed token prefix from zero state and compare final hidden values, recurrent states, logits, top-two ranking, and head audit against incremental execution.
- Emit byte-stable BLAKE3-bound per-step and final decode receipts from a separate argument-free `rwkv-decode-harness` binary.
- Reject state resets, state sharing, stale generated-token input, replay disagreement, non-finite values, caller arguments, subprocesses, and hardware execution paths.

## Impact

- Affected spec: `tenstorrent-native-runtime`
- Affected package: `pkgs/rwkv-layer-harness`
- Existing flake package gains the `rwkv-decode-harness` binary
- Hardware impact: none; no Metalium, Tenstorrent device, owner service, or hardware attempt is permitted
