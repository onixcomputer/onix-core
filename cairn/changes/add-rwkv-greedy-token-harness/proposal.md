# Change: Add a real-weight RWKV-7 greedy-token harness

## Why

The accepted real-weight rung proves only layer-zero execution for two fixed tokens. It does not exercise cross-layer `v_first` interpolation, independent recurrent state for all twelve layers, final model normalization, the untied language-model head, or greedy token selection. Those are the smallest remaining device-free mechanisms between the standalone layer reference and a generated-token claim.

## What Changes

- Extend the existing pinned Rust checkpoint core with reviewed all-layer schema loading and token-local cross-layer `v_first` propagation.
- Execute the fixed BOS/EOS prefix through all twelve RWKV-7 layers while carrying attention, channel-mix, matrix, and oracle state independently per layer.
- Apply the final model normalization and untied `[vocabulary, hidden]` language-model head, then select exactly one greedy token.
- Cross-check the production head result against a separately structured direct BF16-row scalar oracle and reject orientation or top-one disagreement.
- Emit deterministic BLAKE3 fingerprints, finite statistics, top-two logits, margin, per-layer oracle deviations, exact checkpoint identity, and narrow non-claims.
- Preserve the existing layer-zero binary and receipts unchanged while adding a separate argument-free device-free token binary.

## Impact

- Affected spec: `tenstorrent-native-runtime`
- Affected package: `pkgs/rwkv-layer-harness`
- Affected flake output: existing `rwkv-layer-harness` package gains `rwkv-token-harness`
- Hardware impact: none; the change must not invoke Metalium, enumerate a Tenstorrent device, control an owner service, or consume a hardware attempt
