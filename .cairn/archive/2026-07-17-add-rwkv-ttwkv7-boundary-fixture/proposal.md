# Change: Add a real-weight RWKV-to-ttWKV7 boundary fixture

## Why

The packaged ttWKV7 host now represents the checkpoint's 64-wide, 12-head shape, but no canonical artifact carries real checkpoint-derived WKV inputs and retained state across the CPU/model boundary into the ttWKV7 ABI. Synthetic operator inputs cannot establish that the model equations, tensor order, BF16 quantization, state orientation, and ttWKV7 host shape compose.

## What Changes

- Capture the layer-zero second-token WKV boundary for the accepted model-config prefix `[1, 2]`, including the retained pre-state, six exact WKV vectors, raw recurrence output, and post-state.
- Quantize that boundary explicitly to little-endian BF16 in ttWKV7's host input order `[a, w, k, v, r, b]` and publish complete hexadecimal bytes plus per-artifact and combined BLAKE3 identities.
- Recompute expected output and post-state from the BF16 boundary through independent matrix and scalar recurrence paths, retaining complete FP32 source summaries and named deviation evidence.
- Add an argument-free fixture binary and install its deterministic JSON artifact with the existing Rust harness package.
- Preserve every accepted layer, token, decode, text, prompt, and framework receipt unchanged.

## Impact

- Affected spec: `tenstorrent-native-runtime`
- Affected code: `pkgs/rwkv-layer-harness`
- Hardware boundary: no Tenstorrent process, owner-control action, Metalium initialization, ttWKV7 kernel, or new hardware authorization is permitted.
